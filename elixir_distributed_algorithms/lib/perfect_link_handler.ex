defmodule DistributedAlgorithmsApp.PerfectLinkHandler do
  use GenServer
  alias Protobuf
  alias DistributedAlgorithmsApp.AppLayer
  alias DistributedAlgorithmsApp.BestEffortBroadcastLayer
  require Logger

  @message_size_in_bytes 4

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    socket = Map.get(args, :socket)
    pl_memory_pid = Map.get(args, :pl_memory_pid)
    :inet.setopts(socket, active: true)

    state =
      GenServer.call(pl_memory_pid, :get_state)
      |> Map.put(:socket, socket)
      |> Map.put(:pl_memory_pid, pl_memory_pid)

    {:ok, state}
  end

  defp deliver_message(message, state) do
    Logger.info("PERFECT_LINK_HANDLER: Delivering a message...")

    updated_message = %Proto.Message {
      systemId: message.systemId,
      type: :PL_DELIVER,
      plDeliver: %Proto.PlDeliver {sender: extract_sender_process_id(message, state), message: message.networkMessage.message}
    }

    IO.inspect updated_message, label: "Updated plDeliver message from PLL.deliver_message", limit: :infinity

    case Map.get(message, :ToAbstractionId) do
      "app.pl" -> AppLayer.receive_message(updated_message, state)
      "app.beb.pl" -> BestEffortBroadcastLayer.receive_message(updated_message, state)
    end
  end

  defp extract_sender_process_id(message, state) do
    sender_host = message.networkMessage.senderHost
    sender_port = message.networkMessage.senderListeningPort
    sender_process_id_struct = struct(Proto.ProcessId, host: sender_host, port: sender_port, owner: "hub", index: nil, rank: nil)

    case state.process_id_structs do
      nil -> sender_process_id_struct
      structs ->
        condition_lambda = fn x -> x.owner == state.owner and x.index == state.process_index end
        Enum.filter(structs, condition_lambda) |> Enum.at(0)
    end
  end

  @impl true
  def handle_info({:tcp, _socket, packet}, state) do
    Logger.info("PERFECT_LINK_HANDLER: Received packet #{inspect(packet)}")
    <<_::binary-size(@message_size_in_bytes), binary_message::binary>> = packet
    message = Protobuf.decode(binary_message, Proto.Message)
    IO.inspect message, label: "Received message", limit: :infinity

    deliver_message(message, state)

    {:noreply, state}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, state) do
    Logger.info("PERFECT_LINK_HANDLER: Socket is closed")
    {:stop, {:shutdown, "Socket is closed"}, state}
  end

  @impl true
  def handle_info({:tcp_error, _socket, reason}, state) do
    Logger.error("PERFECT_LINK_HANDLER: Tcp error - #{inspect(reason)}")
    {:stop, {:shutdown, "Tcp error: #{inspect(reason)}"}, state}
  end

  def send_broadcast_value_to_hub(message, state) do
    # checked
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
    Logger.info("PERFECT_LINK_HANDLER: #{state.process_id_struct.owner}-#{Integer.to_string(state.process_id_struct.index)} sent confirmation message to the hub")
  end

  def send_broadcast_value_to_process(message, state) do
    destination = message.plSend.destination
    message_to_broadcast = %Proto.Message {
      systemId: state.system_id,
      type: :NETWORK_MESSAGE,
      FromAbstractionId: "app.beb.pl",
      ToAbstractionId: "app.beb.pl",
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
