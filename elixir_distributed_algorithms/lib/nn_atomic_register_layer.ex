defmodule DistributedAlgorithmsApp.NnAtomicRegisterLayer do
  alias Protobuf
  alias DistributedAlgorithmsApp.AppLayer
  alias DistributedAlgorithmsApp.BestEffortBroadcastLayer
  alias DistributedAlgorithmsApp.PerfectLinkLayer
  alias DistributedAlgorithmsApp.TimestampRankPair
  require Logger

  ## CHECKED !!!
  def write_value(message, state) do
    Logger.info("NNAR_ATOMIC_REGISTER: WRITE VALUE AND READ FROM OTHER PROCESSES")

    edited_register = message.plDeliver.message.appWrite.register
    current_register =
      if not Map.has_key?(state.registers, edited_register) do
        IO.puts("CURRENT REGISTER #{edited_register} INITIALIZED.")
        %{timestamp_rank_value_tuple: TimestampRankPair.new(),
          writeval: nil,
          readval: nil,
          read_list: [],
          reading: false,
          acknowledgments: 0,
          request_id: 0}
      else
        IO.puts("CURRENT REGISTER #{edited_register} OBTAINED.")
        Map.get(state.registers, edited_register)
      end

    updated_registers = Map.put(
      state.registers,
      edited_register,
      %{
        timestamp_rank_value_tuple: current_register.timestamp_rank_value_tuple,
        writeval: message.plDeliver.message.appWrite.value,
        readval: nil,
        read_list: [],
        reading: false,
        acknowledgments: 0,
        request_id: current_register.request_id + 1
       }
    )

    new_state = %{state | registers: updated_registers}
    GenServer.call(state.pl_memory_pid, {:save_register_writer_data, new_state.registers})

    broadcasted_message = %Proto.Message {
      type: :BEB_BROADCAST,
      FromAbstractionId: "app.nnar[" <> edited_register <> "]",
      ToAbstractionId: "app.nnar[" <> edited_register <> "].beb",
      bebBroadcast: %Proto.BebBroadcast {
        message: %Proto.Message {
          type: :NNAR_INTERNAL_READ,
          FromAbstractionId: "app.nnar[" <> edited_register <> "]",
          ToAbstractionId: "app.nnar[" <> edited_register <> "]",
          nnarInternalRead: %Proto.NnarInternalRead {
            readId: current_register.request_id + 1
          }
        }
      }
    }

    BestEffortBroadcastLayer.read_register_values(broadcasted_message, new_state)
  end

  def read_value(message, state) do
    Logger.info("NNAR_ATOMIC_REGISTER: READ VALUE AND READ FROM OTHER PROCESSES")

    edited_register = message.plDeliver.message.appRead.register
    current_register = if not Map.has_key?(state.registers, edited_register) do
        Map.put(state.registers, edited_register,
          %{timestamp_rank_value_tuple: TimestampRankPair.new(),
            writeval: nil,
            readval: nil,
            read_list: [],
            reading: true,
            acknowledgments: 0,
            request_id: 0})
      else
        Map.get(state.registers, edited_register)
      end

    updated_registers = Map.put(
      state.registers,
      edited_register,
      %{
        timestamp_rank_value_tuple: current_register.timestamp_rank_value_tuple,
        writeval: nil,
        readval: nil,
        read_list: [],
        reading: true,
        acknowledgments: 0,
        request_id: current_register.request_id + 1
       }
    )

    new_state = %{state | registers: updated_registers}
    GenServer.call(state.pl_memory_pid, {:save_register_reader_data, new_state.registers})

    broadcasted_message = %Proto.Message {
      type: :BEB_BROADCAST,
      FromAbstractionId: "app.nnar[" <> edited_register <> "]",
      ToAbstractionId: "app.nnar[" <> edited_register <> "].beb",
      bebBroadcast: %Proto.BebBroadcast {
        message: %Proto.Message {
          type: :NNAR_INTERNAL_READ,
          FromAbstractionId: "app.nnar[" <> edited_register <> "]",
          ToAbstractionId: "app.nnar[" <> edited_register <> "]",
          nnarInternalRead: %Proto.NnarInternalRead {
            readId: current_register.request_id + 1
          }
        }
      }
    }

    BestEffortBroadcastLayer.read_register_values(broadcasted_message, new_state)
  end

  def receive_message(message, state), do: deliver_message(message, state)

  def deliver_message(message, state) do
    # keys = [:bebDeliver, :message, :type]
    # message_type = get_in(message, Enum.map(keys, &Access.key!(&1)))
    # Logger.info("NN_ATOMIC_REGISTER: RECEIVED A #{message_type} MESSAGE")
    AppLayer.receive_message(message, state)
  end

  def send_app_return_message(message, state) do
    Logger.info("NN ATOMIC REGISTER #{state.owner}-#{state.process_index}: SENT #{message.type} TO HUB")
    response = %Proto.Message {
      type: :PL_SEND,
      plSend: %Proto.PlSend {
        destination: %Proto.ProcessId {
          host: state.hub_address,
          port: state.hub_port
        },
        message: message
      }
    }
    PerfectLinkLayer.send_value_to_hub(response, state)
  end

end
