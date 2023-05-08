defmodule DistributedAlgorithmsApp.NnAtomicRegisterLayer do
  alias Protobuf
  alias DistributedAlgorithmsApp.AppLayer
  alias DistributedAlgorithmsApp.BestEffortBroadcastLayer
  alias DistributedAlgorithmsApp.PerfectLinkLayer
  require Logger

  def write_value(message, state) do
    Logger.info("NNAR_ATOMIC_REGISTER: WRITE VALUE AND READ FROM OTHER PROCESSES")
    new_state = %{state |
      request_id: state.request_id + 1,
      value_to_be_written: message.plDeliver.message.appWrite.value.v,
      register_to_be_written: message.plDeliver.message.appWrite.register
    }

    {request_id, _value_to_be_written, register_to_be_written} = GenServer.call(state.pl_memory_pid, {:save_register_writer_data, new_state.request_id, new_state.value_to_be_written, new_state.register_to_be_written})


    broadcasted_message = %Proto.Message {
      type: :BEB_BROADCAST,
      FromAbstractionId: "app.nnar["<> register_to_be_written <>"]",
      ToAbstractionId: "app.nnar["<> register_to_be_written <> "]" <> ".beb",
      bebBroadcast: %Proto.BebBroadcast {
        message: %Proto.Message {
          type: :NNAR_INTERNAL_READ,
          FromAbstractionId: "app.nnar["<> register_to_be_written <> "]",
          ToAbstractionId: "app.nnar["<> register_to_be_written <> "]",
          nnarInternalRead: %Proto.NnarInternalRead {
            readId: request_id
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

  def broadcast_nnar_write_return(message, state) do
    updated_message =
      message
      |> update_in([Access.key!(:ToAbstractionId)], fn _ -> "app.nnar["<> state.register_to_be_written <>"].beb.pl" end)
      |> update_in([Access.key!(:FromAbstractionId)], fn _ -> "app.nnar["<> state.register_to_be_written <>"].beb.pl" end)

    broadcasted_message = %Proto.Message {
      type: :BEB_BROADCAST,
      FromAbstractionId: "app.nnar[" <> state.register_to_be_written <> "].beb.pl",
      ToAbstractionId: "app.nnar[" <> state.register_to_be_written <> "].beb.pl",
      bebBroadcast: %Proto.BebBroadcast {
        message: updated_message
      }
    }

    Enum.each(state.process_id_structs, fn x ->
      BestEffortBroadcastLayer.send_broadcast_message(broadcasted_message, x, state)
    end)
  end

  def send_app_write_return_message(message, state) do
    Logger.info("NN ATOMIC REGISTER #{state.owner}-#{state.process_index}: SENT APP_WRITE_RETURN TO HUB")
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
