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
      :APP_PROPOSE -> deliver_app_propose_message(message, state)
      type when type in [:APP_WRITE, :APP_READ] -> send_nnar_broadcast_read(message, state)
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

  defp deliver_app_propose_message(message, state) do
    value = message.plDeliver.message.appPropose.value.v
    topic = message.plDeliver.message.appPropose.topic
    Logger.info("APP_LAYER: Received the :APP_PROPOSE message with value #{value} and topic #{topic}")

    GenServer.call(state.pl_memory_pid, :initialize_epfd_layer)
  end

  def receive_uc_decide_event(message, state) do
    app_decide_message = %Proto.Message {
      ToAbstractionId: "app.pl",
      FromAbstractionId: "app.pl",
      type: :PL_SEND,
      plSend: %Proto.PlSend {
        destination: %Proto.ProcessId {host: state.hub_address, port: state.hub_port, owner: "hub", index: 0, rank: 0},
        message: %Proto.Message {
          ToAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
          FromAbstractionId: "app.pl", # be careful with the abstractions, the hub doesn't recognize this one...
          type: :APP_DECIDE,
          appDecide: %Proto.AppDecide {
            value: message.ucDecide.value
          }
        }
      }
    }

    PerfectLinkLayer.send_value_to_hub(app_decide_message, state)
  end

  ## CHECKED !!!
  defp receive_nnar_internal_read_message(message, state) do
    keys = [:bebDeliver, :message, :nnarInternalRead, :readId]
    request_id_received = get_in(message, Enum.map(keys, &Access.key!(&1)))

    keys = [:bebDeliver, :message, :ToAbstractionId]
    register_name =
      get_in(message, Enum.map(keys, &Access.key!(&1)))
      |> then(fn abstraction -> Regex.named_captures(~r/\[(?<register_name>.*)\]/, abstraction) end)
      |> Map.get("register_name")

    abstraction_id = "app.nnar[" <> register_name <> "].pl"
    cut_abstraction_name = fn x -> String.split(x, ".") |> Enum.drop(-1) |> Enum.join(".") end

    registers =
      if not Map.has_key?(state.registers, register_name) do
        Map.put(state.registers, register_name,
          %{
            timestamp_rank_value_tuple: TimestampRankPair.new(),
            writeval: nil,
            readval: nil,
            read_list: [],
            reading: false,
            acknowledgments: 0,
            request_id: request_id_received
           }
        )
      else
        current_register_state = Map.get(state.registers, register_name)
        Map.put(state.registers, register_name,
          %{
            timestamp_rank_value_tuple: current_register_state.timestamp_rank_value_tuple,
            writeval: current_register_state.writeval,
            readval: current_register_state.readval,
            read_list: current_register_state.read_list,
            reading: false,
            acknowledgments: 0,
            request_id: request_id_received
           }
        )
      end

    new_state = %{state | registers: registers}
    GenServer.call(state.pl_memory_pid, {:save_register_writer_data, new_state.registers})

    Logger.info("NNAR_INTERNAL_READ #{state.owner}-#{state.process_index} MESSAGE RECEIVED, SENDING VALUE FROM REGISTER #{register_name}, ABSTRACTION ID #{abstraction_id}")
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
            readId: request_id_received,
            timestamp: Map.get(registers, register_name).timestamp_rank_value_tuple.timestamp,
            writerRank: Map.get(registers, register_name).timestamp_rank_value_tuple.writer_rank,
            value: Map.get(registers, register_name).timestamp_rank_value_tuple.value
          }
        }
      }
    }

    PerfectLinkLayer.send_value_to_process(updated_message, new_state)
  end

  ## CHECKED !!!
  defp receive_nnar_internal_write_message(message, state) do
    received_struct = TimestampRankPair.new(
      message.bebDeliver.message.nnarInternalWrite.timestamp,
      message.bebDeliver.message.nnarInternalWrite.writerRank,
      message.bebDeliver.message.nnarInternalWrite.value
    )

    keys = [:bebDeliver, :message, :ToAbstractionId]
    register_to_write =
      get_in(message, Enum.map(keys, &Access.key!(&1)))
      |> then(fn abstraction -> Regex.named_captures(~r/\[(?<register_name>.*)\]/, abstraction) end)
      |> Map.get("register_name")

    abstraction_id = "app.nnar[" <> register_to_write <> "].pl"
    cut_abstraction_name = fn x -> String.split(x, ".") |> Enum.drop(-1) |> Enum.join(".") end

    Logger.info("NNAR_INTERNAL_WRITE #{state.owner}-#{state.process_index} MESSAGE RECEIVED, WRITING TO REGISTER #{register_to_write}, ABSTRACTION ID #{abstraction_id}")

    if TimestampRankPair.compare(received_struct, Map.get(state.registers, register_to_write).timestamp_rank_value_tuple) do
      GenServer.call(state.pl_memory_pid, {:save_new_timestamp_rank_pair, received_struct, register_to_write})
    end

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

  ## CHECKED
  defp receive_nnar_internal_ack_message(message, state) do
    keys = [:bebDeliver, :message, :ToAbstractionId]
    register_name =
      get_in(message, Enum.map(keys, &Access.key!(&1)))
      |> then(fn abstraction -> Regex.named_captures(~r/\[(?<register_name>.*)\]/, abstraction) end)
      |> Map.get("register_name")

    current_register = GenServer.call(state.pl_memory_pid, {:get_register, register_name})

    if message.bebDeliver.message.nnarInternalAck.readId == current_register.request_id do
      Logger.info("NNAR_INTERNAL_ACK MESSAGE RECEIVED BY #{state.process_id_struct.owner}-#{state.process_id_struct.index}: #{current_register.request_id}")
      acknowledgments = GenServer.call(state.pl_memory_pid, {:increment_ack_counter, register_name})
      n = length(state.process_id_structs)

      abstraction_id = "app.nnar[" <> register_name <> "].pl"

      if acknowledgments > div(n, 2) do
        Logger.info("ACKNOWLEDGMENT MAJORITY")
        GenServer.call(state.pl_memory_pid, {:reset_ack_counter, register_name})
        response =
          if current_register.reading == true do
            Logger.info("READING FLAG IS TRUE #{state.process_id_struct.owner}-#{state.process_id_struct.index}")
            %Proto.Message {
              type: :APP_READ_RETURN,
              FromAbstractionId: abstraction_id,
              ToAbstractionId: abstraction_id,
              appReadReturn: %Proto.AppReadReturn {
                register: register_name,
                value: current_register.readval
              }
            }
          else
            %Proto.Message {
              type: :APP_WRITE_RETURN,
              FromAbstractionId: abstraction_id,
              ToAbstractionId: abstraction_id,
              appWriteReturn: %Proto.AppWriteReturn {
                register: register_name
              }
            }
          end
        new_state = GenServer.call(state.pl_memory_pid, :get_state)
        NnAtomicRegisterLayer.send_app_return_message(response, new_state)
      end
    end
  end

  ## CHECKED !!!
  defp receive_nnar_internal_value_message(message, state) do
    nnar_value = message.bebDeliver.message.nnarInternalValue
    keys = [:bebDeliver, :message, :ToAbstractionId]
    register_name =
      get_in(message, Enum.map(keys, &Access.key!(&1)))
      |> then(fn abstraction -> Regex.named_captures(~r/\[(?<register_name>.*)\]/, abstraction) end)
      |> Map.get("register_name")

    # abstraction_id = "app.nnar[" <> register_name <> "].pl"
    # cut_abstraction_name = fn x -> String.split(x, ".") |> Enum.drop(-1) |> Enum.join(".") end

    if nnar_value.readId == Map.get(state.registers, register_name).request_id do
      new_read_list_entry = TimestampRankPair.new(nnar_value.timestamp, nnar_value.writerRank, nnar_value.value)
      new_read_list = [new_read_list_entry | Map.get(state.registers, register_name).read_list]
      new_state = GenServer.call(state.pl_memory_pid, {:save_register_readlist_entry, new_read_list_entry, register_name})

      if length(new_read_list) > div(length(new_state.process_id_structs), 2) do
        new_timestamp_rank_tuple = Enum.max(new_read_list, fn x, y -> TimestampRankPair.compare(x, y) end)
        GenServer.call(state.pl_memory_pid, {:save_new_timestamp_rank_pair, new_timestamp_rank_tuple, register_name})
        internal_write_message =
          if Map.get(new_state.registers, register_name).reading == true do
            %Proto.NnarInternalWrite {
              readId: nnar_value.readId,
              timestamp: new_timestamp_rank_tuple.timestamp,
              writerRank: new_timestamp_rank_tuple.writer_rank,
              value: Map.get(new_state.registers, register_name).readval
            }
          else
            %Proto.NnarInternalWrite {
              readId: nnar_value.readId,
              timestamp: new_timestamp_rank_tuple.timestamp + 1,
              writerRank: new_state.process_id_struct.rank,
              value: Map.get(new_state.registers, register_name).writeval
            }
          end

        broadcasted_message =
          %Proto.Message {
            type: :BEB_BROADCAST,
            FromAbstractionId: "app.nnar[" <> register_name <> "]",
            ToAbstractionId: "app.nnar[" <> register_name <> "].beb",
            bebBroadcast: %Proto.BebBroadcast {
              message: %Proto.Message {
                type: :NNAR_INTERNAL_WRITE,
                FromAbstractionId: "app",
                ToAbstractionId: "app",
                nnarInternalWrite: internal_write_message
              }
            }
          }

        Enum.each(state.process_id_structs, fn x -> BestEffortBroadcastLayer.send_broadcast_message(broadcasted_message, x, new_state) end)
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

    GenServer.call(state.pl_memory_pid, {:save_process_id_structs, other_process_id_structs, process_id_struct, message.systemId})
  end

end
