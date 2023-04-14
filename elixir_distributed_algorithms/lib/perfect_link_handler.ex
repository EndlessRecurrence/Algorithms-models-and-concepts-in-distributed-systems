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

  defp destroy_process_system(socket) do
    Logger.info("PERFECT_LINK_HANDLER: Hub destroyed old process system")
    :gen_tcp.shutdown(socket, :read_write)
  end

  defp initialize_process_system(socket, message, state) do
    Logger.info("PERFECT_LINK_HANDLER: Hub initialized process system")
    broadcasted_process_id_structs_from_hub = message.networkMessage.message.procInitializeSystem.processes

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

    GenServer.cast(state.pl_memory_pid, {:save_process_id_structs, new_state.process_id_structs, new_state.process_id_struct})
    GenServer.cast(state.pl_memory_pid, {:save_system_id, new_state.system_id})

    :gen_tcp.shutdown(socket, :read_write)
  end

  defp receive_and_share_broadcast_message_with_all_processes(socket, message, state) do
    saved_state = GenServer.call(state.pl_memory_pid, :get_state)
    process_id_struct = Map.get(saved_state, :process_id_struct)
    process_id_structs = Map.get(saved_state, :process_id_structs)
    process_name = saved_state.owner <> "-" <> Integer.to_string(saved_state.process_index)
    value = message.networkMessage.message.appBroadcast.value
    Logger.info("PERFECT_LINK_HANDLER: #{process_name} received an APP_BROADCAST message from the hub containing the value #{value.v}")

    updated_message = message
    |> update_in([Access.key!(:networkMessage), Access.key!(:message), Access.key!(:appBroadcast)], fn _ -> nil end)
    |> update_in([Access.key!(:networkMessage), Access.key!(:message), Access.key!(:type)], fn _ -> :APP_VALUE end)
    |> update_in([Access.key!(:networkMessage), Access.key!(:message), Access.key!(:appValue)], fn _ -> struct(Proto.AppValue, value: value) end)

    send_broadcast_value_to_hub(saved_state.hub_address, saved_state.hub_port, updated_message, process_id_struct)
    send_broadcast_value_to_other_processes(process_id_structs, updated_message, process_id_struct)

    :gen_tcp.shutdown(socket, :read_write)
  end

  defp receive_broadcast_message_and_send_it_to_the_hub(socket, message, state) do
    Logger.info("PERFECT_LINK_HANDLER: Received an APP_VALUE message")
    saved_state = GenServer.call(state.pl_memory_pid, :get_state)
    send_broadcast_value_to_hub(saved_state.hub_address, saved_state.hub_port, message, saved_state.process_id_struct)

    :gen_tcp.shutdown(socket, :read_write)
  end

  @impl true
  def handle_info({:tcp, socket, packet}, state) do
    Logger.info("Received packet: #{inspect(packet)}")
    <<_::binary-size(@message_size_in_bytes), binary_message::binary>> = packet
    message = Protobuf.decode(binary_message, Proto.Message)
    network_message = message.networkMessage

    case network_message.message.type do
      :PROC_DESTROY_SYSTEM -> destroy_process_system(socket)
      :PROC_INITIALIZE_SYSTEM -> initialize_process_system(socket, message, state)
      :APP_BROADCAST -> receive_and_share_broadcast_message_with_all_processes(socket, message, state)
      :APP_VALUE -> receive_broadcast_message_and_send_it_to_the_hub(socket, message, state)
      _ -> raise RuntimeError, message: "PERFECT_LINK_HANDLER_ERROR: Unknown message type"
    end

    {:noreply, state}
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

  defp send_broadcast_value_to_other_processes([], _, _), do: :ok
  defp send_broadcast_value_to_other_processes([process | list_of_processes], message, this_process) when process.rank != this_process.rank do
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
  defp send_broadcast_value_to_other_processes([_ | list_of_processes], message, this_process), do: send_broadcast_value_to_other_processes(list_of_processes, message, this_process)

  defp send_broadcast_value_to_hub(hub_address, hub_port, message, this_process) do
    hub_address_bytes = Regex.split(~r/\./, hub_address)
    hub_address_as_tuple_of_integers = Enum.map(hub_address_bytes, fn byte -> String.to_integer(byte) end) |> List.to_tuple()
    options = [:binary, active: false, packet: :raw]
    {_socket_connection_status, socket} = :gen_tcp.connect(hub_address_as_tuple_of_integers, hub_port, options) #message.networkMessage.senderListeningPort, options)

    updated_message = message
      |> update_in([Access.key!(:networkMessage), Access.key!(:senderHost)], fn _ -> this_process.host end)
      |> update_in([Access.key!(:networkMessage), Access.key!(:senderListeningPort)], fn _ -> this_process.port end)

    encoded_broadcast_message = updated_message |> Protobuf.encode()

    :gen_tcp.send(socket, <<0, 0, 0, byte_size(encoded_broadcast_message)>> <> encoded_broadcast_message)
    Logger.info("PERFECT_LINK_HANDLER: #{this_process.owner}-#{Integer.to_string(this_process.index)} sent confirmation message to the hub")
  end

end
