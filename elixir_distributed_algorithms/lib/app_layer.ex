defmodule DistributedAlgorithmsApp.AppLayer do
  alias Protobuf
  alias DistributedAlgorithmsApp.NnAtomicRegisterLayer
  alias DistributedAlgorithmsApp.BestEffortBroadcastLayer
  alias DistributedAlgorithmsApp.PerfectLinkLayer
  alias DistributedAlgorithmsApp.TimestampRankPair
  require Logger

  def receive_message(message, state) do
    case message.type do
      :PL_DELIVER -> receive_pl_deliver_message(message, state)
      :BEB_DELIVER -> receive_beb_deliver_message(message, state)
    end
  end

  defp receive_pl_deliver_message(message, state) do
    case message.plDeliver.message.type do
      :PROC_DESTROY_SYSTEM -> Logger.info("APP_LAYER: Hub destroyed process system.")
      :PROC_INITIALIZE_SYSTEM -> initialize_system(message, state)
      :APP_BROADCAST -> send_broadcast_message(message, state)
      :APP_WRITE -> send_nnar_broadcast_read(message, state)
      :APP_READ -> send_nnar_broadcast_read(message, state)
    end
  end

  defp receive_beb_deliver_message(message, state) do
    case message.bebDeliver.message.type do
      :APP_VALUE -> receive_app_value_message(message, state)
      :NNAR_INTERNAL_READ -> receive_nnar_internal_read_message(message, state)
      :NNAR_INTERNAL_WRITE -> receive_nnar_internal_write_message(message, state)
      :NNAR_INTERNAL_ACK -> receive_nnar_internal_ack_message(message, state)
      :NNAR_INTERNAL_VALUE -> receive_nnar_internal_value_message(message, state)
    end
  end

  defp receive_nnar_internal_read_message(message, state) do
    keys = [:bebDeliver, :message, :nnarInternalRead, :readId]
    read_id_received = get_in(message, Enum.map(keys, &Access.key!(&1)))

    # abstraction_id = "app.nnar[" <> state.register_to_be_written <> "].pl"
    abstraction_id = "app.nnar[x].pl"
    cut_abstraction_name = fn x -> String.split(x, ".") |> Enum.drop(-1) |> Enum.join(".") end
    updated_message = %Proto.Message {
      type: :PL_SEND,
      FromAbstractionId: abstraction_id,
      ToAbstractionId: abstraction_id,
      plSend: %Proto.PlSend {
        destination: message.bebDeliver.sender,
        message: %Proto.Message {
          type: :NNAR_INTERNAL_VALUE,
          FromAbstractionId: cut_abstraction_name.(abstraction_id),
          ToAbstractionId: cut_abstraction_name.(abstraction_id),
          nnarInternalValue: %Proto.NnarInternalValue {
            readId: read_id_received,
            timestamp: state.timestamp_rank_struct.timestamp,
            writerRank: state.timestamp_rank_struct.writer_rank,
            value: state.timestamp_rank_struct.value
          }
        }
      }
    }

    PerfectLinkLayer.send_value_to_process(updated_message, state)
  end

  defp receive_nnar_internal_write_message(message, state) do
    Logger.info("NNAR_INTERNAL_WRITE #{state.owner}-#{state.process_index} MESSAGE RECEIVED")
    received_struct = TimestampRankPair.new(
      message.bebDeliver.message.nnarInternalWrite.timestamp,
      message.bebDeliver.message.nnarInternalWrite.writerRank,
      message.bebDeliver.message.nnarInternalWrite.value
    )

    if TimestampRankPair.compare(received_struct, state.timestamp_rank_struct) do
      GenServer.call(state.pl_memory_pid, {:save_new_timestamp_rank_pair, received_struct})
    end

    # abstraction_id = "app.nnar[" <> state.register_to_be_written <> "].pl"
    abstraction_id = "app.nnar[x].pl"
    cut_abstraction_name = fn x -> String.split(x, ".") |> Enum.drop(-1) |> Enum.join(".") end
    acknowledgment_message = %Proto.Message {
      type: :PL_SEND,
      FromAbstractionId: abstraction_id,
      ToAbstractionId: abstraction_id,
      plSend: %Proto.PlSend {
        destination: message.bebDeliver.sender,
        message: %Proto.Message {
          type: :NNAR_INTERNAL_ACK,
          FromAbstractionId: abstraction_id,
          ToAbstractionId: cut_abstraction_name.(abstraction_id),
          nnarInternalAck: %Proto.NnarInternalAck {
            readId: message.bebDeliver.message.nnarInternalWrite.readId
          }
        }
      }
    }

    PerfectLinkLayer.send_value_to_process(acknowledgment_message, state)
  end

  defp receive_nnar_internal_ack_message(message, state) when message.bebDeliver.message.nnarInternalAck.readId == state.request_id do
    Logger.info("=============== #{state.process_id_struct.owner}-#{state.process_id_struct.index} =================NNAR_INTERNAL_ACK MESSAGE RECEIVED: #{state.register} #{state.value}=======================================")
    acknowledgments = GenServer.call(state.pl_memory_pid, :increment_ack_counter)
    n = length(state.process_id_structs)
    if acknowledgments > div(n, 2) do
      GenServer.call(state.pl_memory_pid, :reset_ack_counter)
      if state.reading == true do
        GenServer.call(state.pl_memory_pid, {:update_reading_flag, false})
        response = %Proto.Message {
          type: :APP_READ_RETURN,
          appReadReturn: %Proto.AppReadReturn {
            register: state.register,
            value: state.timestamp_rank_struct.value
          }
        }
        new_state = GenServer.call(state.pl_memory_pid, :get_state)
        NnAtomicRegisterLayer.send_app_return_message(response, new_state)
      else
        GenServer.call(state.pl_memory_pid, {:save_register_value, state.register, state.value})
        response = %Proto.Message {
          type: :APP_WRITE_RETURN,
          appWriteReturn: %Proto.AppWriteReturn {
            register: state.register
          }
        }
        new_state = GenServer.call(state.pl_memory_pid, :get_state)
        NnAtomicRegisterLayer.send_app_return_message(response, new_state)
      end
    end
  end
  defp receive_nnar_internal_ack_message(_message, _state), do: nil

  defp receive_nnar_internal_value_message(message, state) do
    nnar_value = message.bebDeliver.message.nnarInternalValue

    if nnar_value.readId == state.request_id do
      new_read_list = [nnar_value | state.read_list]
      GenServer.call(state.pl_memory_pid, {:save_readlist_entries, new_read_list})
      if length(new_read_list) > div(length(state.process_id_structs), 2) do
        value = Enum.max(new_read_list, fn x, y -> x.timestamp > y.timestamp or (x.timestamp == y.timestamp and x.writerRank > y.writerRank) end)
        new_timestamp_rank_pair = %TimestampRankPair{timestamp: value.timestamp, writer_rank: value.writerRank, value: value.value}
        GenServer.call(state.pl_memory_pid, {:save_new_timestamp_rank_pair, new_timestamp_rank_pair})
        GenServer.call(state.pl_memory_pid, {:save_readlist_entries, []})

        Logger.info("APP_LAYER READING=#{state.reading}: STEP 3 -> BROADCASTING NNAR_INTERNAL_WRITE...")
        if state.reading == True do
          broadcasted_message = %Proto.Message {
            type: :BEB_BROADCAST,
            FromAbstractionId: "app.nnar[" <> state.register <> "]",
            ToAbstractionId: "app.nnar[" <> state.register <> "].beb",
            bebBroadcast: %Proto.BebBroadcast {
              message: %Proto.Message {
                type: :NNAR_INTERNAL_WRITE,
                FromAbstractionId: "app",
                ToAbstractionId: "app",
                nnarInternalWrite: %Proto.NnarInternalWrite {
                  readId: value.readId,
                  timestamp: value.timestamp,
                  writerRank: value.writerRank,
                  value: %Proto.Value {
                    defined: true,
                    v: value.value
                  }
                }
              }
            }
          }

          Enum.each(state.process_id_structs, fn x ->
            BestEffortBroadcastLayer.send_broadcast_message(broadcasted_message, x, state)
          end)
        else
          broadcasted_message = %Proto.Message {
            type: :BEB_BROADCAST,
            FromAbstractionId: "app.nnar[" <> state.register <> "]",
            ToAbstractionId: "app.nnar[" <> state.register <> "].beb",
            bebBroadcast: %Proto.BebBroadcast {
              message: %Proto.Message {
                type: :NNAR_INTERNAL_WRITE,
                FromAbstractionId: "app",
                ToAbstractionId: "app",
                nnarInternalWrite: %Proto.NnarInternalWrite {
                  readId: nnar_value.readId,
                  timestamp: value.timestamp + 1,
                  writerRank: state.process_id_struct.rank,
                  value: %Proto.Value {
                    defined: true,
                    v: state.value
                  }
                }
              }
            }
          }

          Enum.each(state.process_id_structs, fn x ->
            BestEffortBroadcastLayer.send_broadcast_message(broadcasted_message, x, state)
          end)
        end
      end
    end
  end

  defp send_broadcast_message(message, state) do
    app_value_message = %Proto.Message {type: :APP_VALUE, appValue: %Proto.AppValue {value: message.plDeliver.message.appBroadcast.value}}

    broadcasted_message = %Proto.Message {
      type: :BEB_BROADCAST,
      FromAbstractionId: "app",
      ToAbstractionId: "app.beb",
      bebBroadcast: %Proto.BebBroadcast {message: app_value_message}
    }

    Enum.each(state.process_id_structs, fn x -> BestEffortBroadcastLayer.send_broadcast_message(broadcasted_message, x, state) end)
    response_message_to_hub = %Proto.Message {
      type: :PL_SEND,
      FromAbstractionId: "app",
      ToAbstractionId: "app.pl",
      plSend: %Proto.PlSend {
        destination: %Proto.ProcessId {host: state.hub_address, port: state.hub_port, owner: "hub", index: 0, rank: 0},
        message: app_value_message
      }
    }

    PerfectLinkLayer.send_value_to_hub(response_message_to_hub, state)
  end

  defp send_nnar_broadcast_read(message, state) do
    case message.plDeliver.message.type do
      :APP_READ -> NnAtomicRegisterLayer.read_value(message, state)
      :APP_WRITE -> NnAtomicRegisterLayer.write_value(message, state)
    end
  end

  def receive_app_value_message(message, state) do
    broadcasted_message = %Proto.Message {
      type: :PL_SEND,
      FromAbstractionId: "app",
      ToAbstractionId: "app.pl",
      plSend: %Proto.PlSend {
        destination: %Proto.ProcessId {host: state.hub_address, port: state.hub_port, owner: "hub", index: 0, rank: 0},
        message: %Proto.Message {type: :APP_VALUE, appValue: message.bebDeliver.message.appValue}
      }
    }

    PerfectLinkLayer.send_value_to_hub(broadcasted_message, state)
  end

  def initialize_system(message, state) do
    broadcasted_process_id_structs_from_hub = message.plDeliver.message.procInitializeSystem.processes

    condition_lambda = fn x -> x.owner == state.owner and x.index == state.process_index end
    process_id_struct = broadcasted_process_id_structs_from_hub |> Enum.filter(fn x -> condition_lambda.(x) end) |> Enum.at(0)
    other_process_id_structs = broadcasted_process_id_structs_from_hub |> Enum.reject(fn x -> condition_lambda.(x) end)

    GenServer.call(state.pl_memory_pid, {:save_process_id_structs, other_process_id_structs, process_id_struct})
    GenServer.call(state.pl_memory_pid, {:save_system_id, message.systemId})
  end

end
