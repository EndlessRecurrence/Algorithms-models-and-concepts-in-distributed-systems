defmodule DistributedAlgorithmsApp.NnAtomicRegisterLayer do
  alias Protobuf
  alias DistributedAlgorithmsApp.AppLayer
  alias DistributedAlgorithmsApp.BestEffortBroadcastLayer
  require Logger

  def write_value(message, state) do
    new_state = %{state |
      request_id: state.request_id + 1,
      value_to_be_written: message.plDeliver.message.appWrite.value.v,
      register_to_be_written: message.plDeliver.message.appWrite.register
    }
    GenServer.cast(state.pl_memory_pid, {:save_register_writer_data, new_state.request_id, new_state.value_to_be_written, new_state.register_to_be_written})

    broadcasted_message = %Proto.Message {
      type: :BEB_BROADCAST,
      FromAbstractionId: "app.nnar["<> new_state.register_to_be_written <>"]",
      ToAbstractionId: "app.nnar["<> new_state.register_to_be_written <> "]" <> ".beb",
      bebBroadcast: %Proto.BebBroadcast {
        message: %Proto.Message {
          type: :NNAR_INTERNAL_READ,
          FromAbstractionId: "app.nnar["<> new_state.register_to_be_written <> "]",
          ToAbstractionId: "app.nnar["<> new_state.register_to_be_written <> "]",
          nnarInternalRead: %Proto.NnarInternalRead {
            readId: state.request_id + 1
          }
        }
      }
    }

    BestEffortBroadcastLayer.read_register_values(broadcasted_message, new_state)
  end

  def receive_message(message, state), do: deliver_message(message, state)

  def deliver_message(message, state) do
    keys = [:bebDeliver, :message, :type]
    message_type = get_in(message, Enum.map(keys, &Access.key!(&1)))
    Logger.info("NN_ATOMIC_REGISTER: RECEIVED A #{message_type} MESSAGE")
    AppLayer.receive_message(message, state)
  end

end
