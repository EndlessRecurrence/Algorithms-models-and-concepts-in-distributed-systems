defmodule DistributedAlgorithmsApp.PerfectLinkHandler do
  use GenServer
  alias Protobuf
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
      |> Map.put(:system_id, nil)

    {:ok, state}
  end

  @impl true
  def handle_info({:tcp_closed, _socket}, state) do
    Logger.info("Socket is closed")
    {:stop, {:shutdown, "Socket is closed"}, state}
  end

  @impl true
  def handle_info({:tcp_error, _socket, reason}, state) do
    Logger.error("Tcp error: #{inspect(reason)}")
    {:stop, {:shutdown, "Tcp error: #{inspect(reason)}"}, state}
  end

  @impl true
  def handle_info({:tcp, socket, packet}, state) do
    Logger.info("Received packet: #{inspect(packet)}")
    <<_::binary-size(@message_size_in_bytes), binary_message::binary>> = packet
    message = Protobuf.decode(binary_message, Proto.Message)
    network_message = message.networkMessage

    # IO.puts "======================= Message ============================="
    # IO.inspect(message, limit: :infinity)
    # IO.puts "======================= Network message (type #{network_message.message.type}) ============================="
    # IO.inspect(network_message.message, limit: :infinity)
    # IO.puts "======================================================================"

    case network_message.message.type do
      :PROC_DESTROY_SYSTEM ->
        Logger.info("PERFECT_LINK_HANDLER: Hub destroyed old process system")
        {:noreply, state}

      :PROC_INITIALIZE_SYSTEM ->
        Logger.info("PERFECT_LINK_HANDLER: Hub initialized process system")
        broadcasted_process_id_structs_from_hub = network_message.message.procInitializeSystem.processes

        filtered_process_structs =
          broadcasted_process_id_structs_from_hub
            |> Enum.filter(fn x ->
              x.owner == state.owner and x.index == state.process_index
            end)

        new_state =
          state
          |> Map.put(:process_id_struct, Enum.at(filtered_process_structs, 0))
          |> Map.put(:process_id_structs, broadcasted_process_id_structs_from_hub)
          |> Map.put(:system_id, message.systemId)
        # IO.inspect new_state, label: "FROM PERFECT_LINK_HANDLER: New state after process initialization", limit: :infinity
        GenServer.cast(state.pl_memory_pid, {:save_process_id_structs, new_state.process_id_structs, new_state.process_id_struct})
        GenServer.cast(state.pl_memory_pid, {:save_system_id, new_state.system_id})
        :gen_tcp.close(socket)
        {:noreply, new_state}

      :APP_BROADCAST ->
        Logger.info("PERFECT_LINK_HANDLER: Received an APP_BROADCAST message")
        saved_state = GenServer.call(state.pl_memory_pid, :get_state)
        process_id_struct = Map.get(saved_state, :process_id_struct)
        process_id_structs = Map.get(saved_state, :process_id_structs)
        IO.inspect state, label: "FROM PERFECT_LINK_HANDLER: State from APP_BROADCAST case branch", limit: :infinity
        IO.inspect saved_state, label: "FROM PERFECT_LINK_HANDLER: Saved state obtained from PerfectLinkLayerMemory process in APP_BROADCAST case branch", limit: :infinity
        IO.inspect process_id_structs, label: "FROM PERFECT_LINK_HANDLER: Process id structs from APP_BROADCAST case branch", limit: :infinity
        IO.inspect process_id_struct, label: "FROM PERFECT_LINK_HANDLER: Process id struct from APP_BROADCAST case branch", limit: :infinity

        Logger.info("PERFECT_LINK_HANDLER: Hub orders process #{saved_state.owner <> "-" <> Integer.to_string(saved_state.process_index)} to broadcast value #{network_message.message.appBroadcast.value.v}.")

        value = message.networkMessage.message.appBroadcast.value
        updated_message = message
        |> update_in([Access.key!(:networkMessage), Access.key!(:message), Access.key!(:appBroadcast)], fn _ -> nil end)
        |> update_in([Access.key!(:networkMessage), Access.key!(:message), Access.key!(:type)], fn _ -> :APP_VALUE end)
        |> update_in([Access.key!(:networkMessage), Access.key!(:message), Access.key!(:appValue)], fn _ -> struct(Proto.AppValue, value: value) end)

        send_broadcast_value_to_hub(updated_message, process_id_struct)
        send_broadcast_value_to_other_processes(process_id_structs, updated_message, process_id_struct)
        {:noreply, state}

      :APP_VALUE ->
        Logger.info("PERFECT_LINK_HANDLER: Received an APP_VALUE message")
        saved_state = GenServer.call(state.pl_memory_pid, :get_state)
        process_id_struct = Map.get(saved_state, :process_id_struct)

        IO.inspect network_message, label: "APP_VALUE network message", limit: :infinity
        send_broadcast_value_to_hub(message, process_id_struct)
        {:noreply, state}

      true -> {:noreply, state}
    end
  end


  def send_broadcast_value_to_other_processes([], _, _), do: :ok
  def send_broadcast_value_to_other_processes([process | list_of_processes], message, this_process) when process.rank != this_process.rank do
    address_bytes = Regex.split(~r/\./, process.host)
    address_as_tuple_of_integers = Enum.map(address_bytes, fn byte -> String.to_integer(byte) end) |> List.to_tuple()
    options = [:binary, active: false, packet: :raw]
    {_socket_connection_status, socket} = :gen_tcp.connect(address_as_tuple_of_integers, process.port, options)

    encoded_broadcast_message = message
      |> update_in([Access.key!(:FromAbstractionId)], fn _ -> "app.beb.pl" end)
      |> update_in([Access.key!(:ToAbstractionId)], fn _ -> "app.beb.pl" end)
      |> update_in([Access.key!(:networkMessage), Access.key!(:message), Access.key!(:FromAbstractionId)], fn _ -> "app" end)
      |> update_in([Access.key!(:networkMessage), Access.key!(:message), Access.key!(:ToAbstractionId)], fn _ -> "app" end)
      |> Protobuf.encode()

    :gen_tcp.send(socket, <<0, 0, 0, byte_size(encoded_broadcast_message)>> <> encoded_broadcast_message)
    Logger.info("PERFECT_LINK_HANDLER: Process #{this_process.owner}-#{Integer.to_string(this_process.index)} sent broadcast message to process #{process.owner}-#{Integer.to_string(process.index)}.")
    send_broadcast_value_to_other_processes(list_of_processes, message, this_process)
  end
  def send_broadcast_value_to_other_processes([_ | list_of_processes], message, this_process), do:
    send_broadcast_value_to_other_processes(list_of_processes, message, this_process)

  def send_broadcast_value_to_hub(message, this_process) do
    address_bytes = Regex.split(~r/\./, message.networkMessage.senderHost)
    IO.inspect address_bytes
    address_as_tuple_of_integers = Enum.map(address_bytes, fn byte -> String.to_integer(byte) end) |> List.to_tuple()
    options = [:binary, active: false, packet: :raw]
    {_socket_connection_status, socket} = :gen_tcp.connect(address_as_tuple_of_integers, 5000, options) #message.networkMessage.senderListeningPort, options)

    updated_message = message
      |> update_in([Access.key!(:networkMessage), Access.key!(:senderHost)], fn _ -> this_process.host end)
      |> update_in([Access.key!(:networkMessage), Access.key!(:senderListeningPort)], fn _ -> this_process.port end)

    encoded_broadcast_message = updated_message |> Protobuf.encode()

    IO.inspect updated_message, limit: :infinity, label: "PERFECT_LINK_HANDLER: #{this_process.owner}-#{Integer.to_string(this_process.index)} message for the hub"
    :gen_tcp.send(socket, <<0, 0, 0, byte_size(encoded_broadcast_message)>> <> encoded_broadcast_message)
    Logger.info("PERFECT_LINK_HANDLER: #{this_process.owner}-#{Integer.to_string(this_process.index)} sent confirmation message to the hub")
  end

  @spec generate_process_registration_message(
    sender_address :: String.t(),
    sender_port :: integer(),
    owner :: String.t(),
    process_index :: integer()) :: Proto.Message
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
    Logger.info("PERFECT_LINK_HANDLER: #{nickname}-#{Integer.to_string(process_index)}'s registration message sent to the hub.")
  end

end
