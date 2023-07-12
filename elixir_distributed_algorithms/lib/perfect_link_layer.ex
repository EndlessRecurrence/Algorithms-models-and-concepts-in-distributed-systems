defmodule DistributedAlgorithmsApp.PerfectLinkLayer do
  require Logger
  alias DistributedAlgorithmsApp.PerfectLinkConnectionHandler
  alias DistributedAlgorithmsApp.ProcessMemory
  alias DistributedAlgorithmsApp.AppLayer
  alias DistributedAlgorithmsApp.BestEffortBroadcastLayer
  alias DistributedAlgorithmsApp.EpochConsensus
  alias DistributedAlgorithmsApp.EpochChange

  def accept(port, process_index, nickname, hub_address, hub_port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: 0, active: false, reuseaddr: true])

    register_process(hub_address, hub_port, process_index, port, nickname)
    pl_memory_pid = start_layer_memory_process!(hub_address, hub_port, process_index, nickname)

    loop_acceptor(socket, pl_memory_pid)
  end

  defp start_layer_memory_process!(hub_address, hub_port, process_index, nickname) do
    initial_state = %{
      hub_address: hub_address,
      hub_port: hub_port,
      process_index: process_index,
      owner: nickname,
      process_id_structs: nil,
      process_id_struct: nil,
      registers: %{},
    }

    case ProcessMemory.start_link(initial_state) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> "Process #{pid} already started."
      {:error, reason} -> raise RuntimeError, message: reason
      _ -> raise RuntimeError, message: "start_link ignored, process failed to start."
    end
  end

  defp loop_acceptor(socket, pl_memory_pid) do
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, pid} =
      DynamicSupervisor.start_child(PerfectLinkConnectionHandler.DynamicSupervisor, %{
        id: PerfectLinkConnectionHandler,
        start: {PerfectLinkConnectionHandler, :start_link, [%{socket: client, pl_memory_pid: pl_memory_pid}]},
        type: :worker,
        restart: :transient
      })

    :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket, pl_memory_pid)
  end

  def generate_process_registration_message(sender_address, sender_port, owner, process_index) do
    %Proto.Message{
      type: :NETWORK_MESSAGE,
      networkMessage: %Proto.NetworkMessage{
        senderHost: sender_address,
        senderListeningPort: sender_port,
        message: %Proto.Message{
          type: :PROC_REGISTRATION,
          procRegistration: %Proto.ProcRegistration{
            owner: owner,
            index: process_index
          }
        }
      }
    }
  end

  def register_process(hub_address, hub_port, process_index, port, nickname) do
    address_bytes = Regex.split(~r/\./, hub_address)
    address_as_tuple_of_integers = Enum.map(address_bytes, fn byte -> String.to_integer(byte) end) |> List.to_tuple()
    options = [:binary, active: false, packet: :raw]
    {_socket_connection_status, socket} = :gen_tcp.connect(address_as_tuple_of_integers, hub_port, options)

    encoded_registration_message =
      generate_process_registration_message("127.0.0.1", port, nickname, process_index)
        |> Protobuf.encode()

    :gen_tcp.send(socket, <<0, 0, 0, byte_size(encoded_registration_message)>> <> encoded_registration_message)
  end

  def deliver_message(message, state) do
    updated_message = %Proto.Message {
      systemId: message.systemId,
      type: :PL_DELIVER,
      plDeliver: %Proto.PlDeliver {sender: extract_sender_process_id(message, state), message: message.networkMessage.message}
    }

    keys = [:plDeliver, :message, :ToAbstractionId]
    to_abstraction_id = message
      |> Map.get(:ToAbstractionId)
      |> then(fn x -> if x == nil, do: "", else: x end)

    deep_to_abstraction_id = message
      |> get_in(Enum.map(keys, &Access.key!(&1)))
      |> then(fn x -> if x == nil, do: "", else: x end)

    message_type = message.networkMessage.message.type

    cond do
      message_type == :EPFD_INTERNAL_HEARTBEAT_REQUEST -> send(state.epfd_id, {message_type, updated_message, state})
      message_type == :EPFD_INTERNAL_HEARTBEAT_REPLY -> send(state.epfd_id, {message_type, updated_message, state})
      message_type == :EP_INTERNAL_STATE -> EpochConsensus.deliver_ep_internal_state_message(message, state)
      message_type == :EP_INTERNAL_ACCEPT -> EpochConsensus.deliver_ep_internal_accept_message(message, state)
      message_type == :EC_INTERNAL_NACK -> EpochChange.deliver_ec_internal_nack_message(message, state)
      String.contains?(to_abstraction_id, "beb") -> BestEffortBroadcastLayer.receive_message(updated_message, state)
      Regex.run(~r/nnar/, to_abstraction_id) != nil -> BestEffortBroadcastLayer.receive_message(updated_message, state)
      Regex.run(~r/nnar/, deep_to_abstraction_id) != nil -> BestEffortBroadcastLayer.receive_message(updated_message, state)
      to_abstraction_id == "app.pl" -> AppLayer.receive_message(updated_message, state)
      true -> AppLayer.receive_message(updated_message, state)
    end
  end

  def extract_sender_process_id(message, state) do
    sender_host = message.networkMessage.senderHost
    sender_port = message.networkMessage.senderListeningPort
    sender_process_id_struct = struct(Proto.ProcessId, host: sender_host, port: sender_port, owner: nil, index: nil, rank: nil)

    case state.process_id_structs do
      nil ->
        sender_process_id_struct
        |> update_in([Access.key!(:owner)], fn _ -> "hub" end)
      structs ->
        condition_lambda = fn x -> x.host == sender_host and x.port == sender_port end
        Enum.filter(structs, condition_lambda) |> Enum.at(0)
    end
  end

  def send_value_to_hub(message, state) do
    destination = message.plSend.destination
    message_to_broadcast = %Proto.Message {
      systemId: state.system_id,
      type: :NETWORK_MESSAGE,
      FromAbstractionId: "app.pl",
      ToAbstractionId: "app.pl",
      networkMessage: %Proto.NetworkMessage {
        senderHost: state.process_id_struct.host,
        senderListeningPort: state.process_id_struct.port,
        message: message.plSend.message
      }
    }

    encoded_broadcast_message = Protobuf.encode(message_to_broadcast)

    hub_address_bytes = Regex.split(~r/\./, destination.host)
    hub_address_as_tuple_of_integers = Enum.map(hub_address_bytes, fn byte -> String.to_integer(byte) end) |> List.to_tuple()
    options = [:binary, active: false, packet: :raw]
    {_socket_connection_status, socket} = :gen_tcp.connect(hub_address_as_tuple_of_integers, destination.port, options)

    :gen_tcp.send(socket, <<0, 0, 0, byte_size(encoded_broadcast_message)>> <> encoded_broadcast_message)
  end

  def send_value_to_process(message, state) do
    destination = message.plSend.destination
    {:ok, to_abstraction_id} = Map.fetch(message, :ToAbstractionId)

    message_to_broadcast = %Proto.Message {
      systemId: state.system_id,
      type: :NETWORK_MESSAGE,
      FromAbstractionId: to_abstraction_id,
      ToAbstractionId: to_abstraction_id,
      networkMessage: %Proto.NetworkMessage {
        senderHost: state.process_id_struct.host,
        senderListeningPort: state.process_id_struct.port,
        message: message.plSend.message
      }
    }

    encoded_broadcast_message = Protobuf.encode(message_to_broadcast)

    process_address_bytes = Regex.split(~r/\./, destination.host)
    process_address_as_tuple_of_integers = Enum.map(process_address_bytes, fn byte -> String.to_integer(byte) end) |> List.to_tuple()
    options = [:binary, active: false, packet: :raw]
    {_socket_connection_status, socket} = :gen_tcp.connect(process_address_as_tuple_of_integers, destination.port, options)

    :gen_tcp.send(socket, <<0, 0, 0, byte_size(encoded_broadcast_message)>> <> encoded_broadcast_message)
  end
end
