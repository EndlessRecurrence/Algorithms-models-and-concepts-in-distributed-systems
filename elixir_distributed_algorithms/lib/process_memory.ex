defmodule DistributedAlgorithmsApp.ProcessMemory do
  use GenServer
  require Logger
  alias DistributedAlgorithmsApp.EventuallyPerfectFailureDetector

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    {:ok, args}
  end

  ## CHECKED !!!
  @impl true
  def handle_call({:save_process_id_structs, process_id_structs, process_id_struct, system_id}, _from, state) do
    new_state = state
      |> Map.put(:process_id_struct, process_id_struct)
      |> Map.put(:process_id_structs, process_id_structs)
      |> Map.put(:system_id, system_id)
      |> Map.put(:consensus_dictionary, %{})
      |> Map.put(:pl_memory_pid, self())

    {:reply, {process_id_structs, process_id_struct}, new_state}
  end

  @impl true
  def handle_call({:initialize_epfd_layer, topic_name}, _from, state) do
    Logger.info("PROCESS_MEMORY: SAVE_PROCESS_ID_STRUCTS")

    if Map.has_key?(state, :epfd_id) do
      Process.exit(state.epfd_id, :kill)
    end

    leader = Enum.min_by(state.process_id_structs, fn x -> x.rank end)

    epfd_state = Map.put(state, :consensus_dictionary, Map.put(state.consensus_dictionary, topic_name, %{
      ### eventually perfect failure detector variables
      alive: state.process_id_structs,
      suspected: [],
      initial_delay: 100, # 100 milliseconds, 0.1 seconds
      delay: 100, # 100 milliseconds, 0.1 seconds
      ### epoch change variables
      leader: leader,
      trusted: leader,
      lastts: 0,
      ts: state.process_id_struct.rank,
      ### epoch consensus variables
      valts_val_pair: {0, %Proto.Value{defined: false, v: nil}},
      tmpval: %Proto.Value{defined: false, v: nil},
      states: List.duplicate(nil, length(state.process_id_structs)),
      accepted: 0,
      ### uniform consensus variables
      val: nil,
      proposed: false,
      decided: false,
      # Obtain the leader l_0 of the initial epoch with timestamp 0 from epoch-change inst. ec;
      # Initialize a new instance ep.0 of epoch consensus with timestamp 0, leader l_0 , and state (0, ⊥);
      ets_leader_pair: {0, leader},
      newts_newl_pair: {0, leader},
    }))

    epfd_id =
      case EventuallyPerfectFailureDetector.start_link({epfd_state, topic_name}) do
        {:ok, pid} -> pid
        {:error, {:already_started, pid}} -> "EPFD #{pid} already started."
        {:error, reason} -> raise RuntimeError, message: reason
        _ -> raise RuntimeError, message: "start_link ignored, EPFD failed to start."
      end

    new_state = epfd_state
      |> Map.put(:epfd_id, epfd_id)

    {:reply, new_state, new_state}
  end

  @impl true
  def handle_call({:update_suspected_list, new_suspected, topic}, _from, state) do
    new_consensus_dictionary = Map.get(state.consensus_dictionary, topic)
      |> Map.put(:suspected, new_suspected)
    new_state = state |> Map.put(:consensus_dictionary, new_consensus_dictionary)
    {:reply, new_suspected, new_state}
  end

  @impl true
  def handle_call({:update_leader, new_leader, topic}, _from, state) do
    new_consensus_dictionary = Map.get(state.consensus_dictionary, topic)
      |> Map.put(:leader, new_leader)
    new_state = state |> Map.put(:consensus_dictionary, new_consensus_dictionary)
    {:reply, new_leader, new_state}
  end

  @impl true
  def handle_call({:update_trusted, new_trusted, topic}, _from, state) do
    new_consensus_dictionary = Map.get(state.consensus_dictionary, topic)
      |> Map.put(:trusted, new_trusted)
    new_state = state |> Map.put(:consensus_dictionary, new_consensus_dictionary)
    {:reply, new_trusted, new_state}
  end

  @impl true
  def handle_call({:update_ts, new_ts, topic}, _from, state) do
    new_consensus_dictionary = Map.get(state.consensus_dictionary, topic)
      |> Map.put(:ts, new_ts)
    new_state = state |> Map.put(:consensus_dictionary, new_consensus_dictionary)
    {:reply, new_ts, new_state}
  end

  @impl true
  def handle_call({:update_tmpval, proposed_value, topic}, _from, state) do
    new_consensus_dictionary = Map.get(state.consensus_dictionary, topic)
      |> Map.put(:tmpval, proposed_value)
    new_state = state |> Map.put(:consensus_dictionary, new_consensus_dictionary)
    {:reply, proposed_value, new_state}
  end

  @impl true
  def handle_call({:update_val, value, topic}, _from, state) do
    new_consensus_dictionary = Map.get(state.consensus_dictionary, topic)
      |> Map.put(:val, value)
    new_state = state |> Map.put(:consensus_dictionary, new_consensus_dictionary)
    {:reply, value, new_state}
  end

  @impl true
  def handle_call({:update_valts_val_pair, new_pair, topic}, _from, state) do
    new_consensus_dictionary = Map.get(state.consensus_dictionary, topic)
      |> Map.put(:valts_val_pair, new_pair)
    new_state = state |> Map.put(:consensus_dictionary, new_consensus_dictionary)
    {:reply, new_pair, new_state}
  end

  @impl true
  def handle_call({:update_states_pair, rank, new_pair, topic}, _from, state) do
    new_states_list = List.replace_at(state.states, rank, new_pair)
    new_consensus_dictionary = Map.get(state.consensus_dictionary, topic)
      |> Map.put(:states, new_states_list)
    new_state = state |> Map.put(:consensus_dictionary, new_consensus_dictionary)
    {:reply, new_states_list, new_state}
  end

  @impl true
  def handle_call({:update_accepted, new_accepted, topic}, _from, state) do
    new_consensus_dictionary = Map.get(state.consensus_dictionary, topic)
      |> Map.put(:accepted, new_accepted)
    new_state = state |> Map.put(:consensus_dictionary, new_consensus_dictionary)
    {:reply, new_accepted, new_state}
  end

  @impl true
  def handle_call({:reset_states, topic}, _from, state) do
    new_states = List.duplicate(nil, length(state.process_id_structs))
    new_consensus_dictionary = Map.get(state.consensus_dictionary, topic)
      |> Map.put(:states, new_states)
    new_state = state |> Map.put(:consensus_dictionary, new_consensus_dictionary)
    {:reply, [], new_state}
  end

  @impl true
  def handle_call({:update_newts_newl_pair, newts_newl_pair, topic}, _from, state) do
    new_consensus_dictionary = Map.get(state.consensus_dictionary, topic)
      |> Map.put(:newts_newl_pair, newts_newl_pair)
    new_state = state |> Map.put(:consensus_dictionary, new_consensus_dictionary)
    {:reply, newts_newl_pair, new_state}
  end

  @impl true
  def handle_call({:update_ets_leader_pair, new_ets_leader_pair, topic}, _from, state) do
    new_consensus_dictionary = Map.get(state.consensus_dictionary, topic)
      |> Map.put(:ets_leader_pair, new_ets_leader_pair)
    new_state = state |> Map.put(:consensus_dictionary, new_consensus_dictionary)
    {:reply, new_ets_leader_pair, new_state}
  end

  ## CHECKED !!!
  @impl true
  def handle_call({:save_new_timestamp_rank_pair, timestamp_rank_value_tuple, register_name}, _from, state) do
    # Logger.info("PROCESS_MEMORY OF #{state.process_id_struct.owner}-#{state.process_id_struct.index}: SAVE_NEW_TIMESTAMP_RANK_PAIR")
    current_register = Map.get(state.registers, register_name)
    new_readval = if current_register.reading == true, do: timestamp_rank_value_tuple.value, else: current_register.readval
    updated_registers = Map.put(
      state.registers,
      register_name,
      %{
        timestamp_rank_value_tuple: timestamp_rank_value_tuple,
        writeval: current_register.writeval,
        readval: new_readval,
        read_list: [],
        reading: current_register.reading,
        acknowledgments: current_register.acknowledgments,
        request_id: current_register.request_id
       }
    )

    new_state = state
      |> Map.put(:registers, updated_registers)

    {:reply, timestamp_rank_value_tuple, new_state}
  end

  @impl true
  def handle_call({:get_register, register_name}, _from, state) do
    register = Map.get(state.registers, register_name)
    {:reply, register, state}
  end

  ## CHECKED !!!
  @impl true
  def handle_call({:save_register_writer_data, registers}, _from, state) do
    #Logger.info("PROCESS_MEMORY OF #{state.process_id_struct.owner}-#{state.process_id_struct.index}: SAVE_REGISTER_WRITER_DATA")
    new_state = state |> Map.put(:registers, registers)
    {:reply, registers, new_state}
  end

  ## CHECKED !!!
  @impl true
  def handle_call({:save_register_reader_data, registers}, _from, state) do
    #Logger.info("PROCESS_MEMORY OF #{state.process_id_struct.owner}-#{state.process_id_struct.index}: SAVE_REGISTER_READER_DATA")
    new_state = state |> Map.put(:registers, registers)
    {:reply, registers, new_state}
  end

  ## CHECKED !!!
  @impl true
  def handle_call({:save_register_readlist_entry, timestamp_rank_value_tuple, register_name}, _from, state) do
    #Logger.info("PROCESS_MEMORY OF #{state.process_id_struct.owner}-#{state.process_id_struct.index}: SAVE_REGISTER_READLIST_ENTRY")
    current_register = Map.get(state.registers, register_name)
    updated_registers = Map.put(
      state.registers,
      register_name,
      Map.put(current_register, :read_list, [timestamp_rank_value_tuple | current_register.read_list])
    )

    new_state = state
      |> Map.put(:registers, updated_registers)

    {:reply, new_state, new_state}
  end

  ## CHECKED !!!
  @impl true
  def handle_call({:increment_ack_counter, register_name}, _from, state) do
    #Logger.info("PROCESS_MEMORY OF #{state.process_id_struct.owner}-#{state.process_id_struct.index}: INCREMENT_ACK_COUNTER")
    current_register = Map.get(state.registers, register_name)

    updated_registers = Map.put(
      state.registers,
      register_name,
      Map.put(current_register, :acknowledgments, current_register.acknowledgments + 1)
    )

    new_state = state
      |> Map.put(:registers, updated_registers)

    {:reply, current_register.acknowledgments + 1, new_state}
  end

  @impl true
  def handle_call({:reset_ack_counter, register_name}, _from, state) do
    #Logger.info("PROCESS_MEMORY OF #{state.process_id_struct.owner}-#{state.process_id_struct.index}: RESET_ACK_COUNTER")
    current_register = Map.get(state.registers, register_name)
    updated_content =
      Map.put(current_register, :acknowledgments, 0) |> Map.put(:reading, false)

    updated_registers = Map.put(state.registers, register_name, updated_content)
    new_state = state
      |> Map.put(:registers, updated_registers)

    {:reply, 0, new_state}
  end

  ## CHECKED !!!
  @impl true
  def handle_call(:get_state, _from, state) do
    #Logger.info("PROCESS_MEMORY: GET_STATE EVENT")
    {:reply, state, state}
  end

end
