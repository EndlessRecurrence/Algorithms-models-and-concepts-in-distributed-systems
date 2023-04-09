defmodule DistributedAlgorithmsApp.PerfectLinkHandler do
  use GenServer
  alias Protobuf
  require Logger

  @message_size_in_bytes 4

  def start_link(args, opts) do
    GenServer.start_link(__MODULE__, args, opts)
  end

  @impl true
  def init(args) do
    socket = Map.get(args, :socket)
    :inet.setopts(socket, active: true)
    {:ok, %{socket: socket, process_info: []}}
  end

  @impl true
  def handle_info({:tcp, socket, packet}, state) do
    Logger.info("Received packet: #{inspect(packet)}")
    <<_::binary-size(@message_size_in_bytes), binary_message::binary>> = packet
    network_message = Protobuf.decode(binary_message, Proto.Message).networkMessage

    IO.puts "======================= Network message (type #{network_message.message.type}) ============================="
    IO.inspect network_message.message
    IO.puts "======================================================================"

    cond do
      network_message.message.type == :PROC_DESTROY_SYSTEM ->
        Logger.info("Hub destroyed process system")
        {:noreply, state}
      network_message.message.type == :PROC_INITIALIZE_SYSTEM ->
        Logger.info("Hub initialized process system")
        new_state = %{state | process_info: network_message.message.procInitializeSystem.processes}
        IO.inspect new_state
        {:noreply, new_state}
      true -> false
    end
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

  def register_process(hub_address, hub_port, process_index) do
    address_bytes = Regex.split(~r/\./, hub_address)
    address_as_tuple_of_integers = Enum.map(address_bytes, fn byte -> String.to_integer(byte) end) |> List.to_tuple()
    options = [:binary, active: false, packet: :raw]
    {socket_connection_status, socket} = :gen_tcp.connect(address_as_tuple_of_integers, hub_port, options)
    port = Application.get_env(:elixir_distributed_algorithms, :port)

    encoded_registration_message =
      generate_process_registration_message("127.0.0.1", port, "george", process_index)
        |> Protobuf.encode()

    IO.inspect Protobuf.decode(encoded_registration_message, Proto.Message).networkMessage.message
    :gen_tcp.send(socket, <<0,0,0,byte_size(encoded_registration_message)>> <> encoded_registration_message)
  end

end
