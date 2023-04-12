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
    :inet.setopts(socket, active: true)
    {:ok,
      %{socket: socket,
        process_index: Map.get(args, :process_index),
        owner: Map.get(args, :owner),
        process_id_struct: %{},
        process_id_structs: [],
        system_id: nil
       }
    }
  end

  @impl true
  def handle_info({:tcp, socket, packet}, state) do
    Logger.info("Received packet: #{inspect(packet)}")
    <<_::binary-size(@message_size_in_bytes), binary_message::binary>> = packet
    message = Protobuf.decode(binary_message, Proto.Message)
    network_message = message.networkMessage

    IO.puts "======================= Message ============================="
    IO.inspect(message, limit: :infinity)
    IO.puts "======================= Network message (type #{network_message.message.type}) ============================="
    IO.inspect(network_message.message, label: :infinity)
    IO.puts "======================================================================"

    case network_message.message.type do
      :PROC_DESTROY_SYSTEM ->
        Logger.info("Hub destroyed old process system")
        {:noreply, state}

      :PROC_INITIALIZE_SYSTEM ->
        Logger.info("Hub initialized process system:")
        broadcasted_process_id_structs_from_hub = network_message.message.procInitializeSystem.processes

        filtered_process_structs =
          broadcasted_process_id_structs_from_hub
            |> Enum.filter(fn x ->
              x.owner == state.owner and x.index == state.process_index
            end)

        new_state = %{state |
          process_id_struct: Enum.at(filtered_process_structs, 0),
          process_id_structs: broadcasted_process_id_structs_from_hub,
          system_id: message.systemId}
        IO.inspect new_state
        {:noreply, new_state}

      :APP_BROADCAST ->
        Logger.info("Hub orders process #{state.owner <> "-" <> Integer.to_string(state.process_index)} to broadcast value #{network_message.message.appBroadcast.value.v}.")
        {:noreply, state}

      true -> {:noreply, state}
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

  def register_process(hub_address, hub_port, process_index, port, nickname) do
    address_bytes = Regex.split(~r/\./, hub_address)
    address_as_tuple_of_integers = Enum.map(address_bytes, fn byte -> String.to_integer(byte) end) |> List.to_tuple()
    options = [:binary, active: false, packet: :raw]
    {socket_connection_status, socket} = :gen_tcp.connect(address_as_tuple_of_integers, hub_port, options)

    encoded_registration_message =
      generate_process_registration_message("127.0.0.1", port, nickname, process_index)
        |> Protobuf.encode()

    :gen_tcp.send(socket, <<0, 0, 0, byte_size(encoded_registration_message)>> <> encoded_registration_message)
    Logger.info("#{nickname <> "-" <> Integer.to_string(process_index)}'s registration message sent to the hub.")
  end

end
