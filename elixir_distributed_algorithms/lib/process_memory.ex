defmodule DistributedAlgorithmsApp.ProcessMemory do
  use GenServer
  require Logger

  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  @impl true
  def init(args) do
    {:ok, args}
  end

  @impl true
  def handle_call({:save_process_id_structs, process_id_structs, process_id_struct}, _from, state) do
    Logger.info("PROCESS_MEMORY: SAVE_PROCESS_ID_STRUCTS")
    new_state = state
      |> Map.put(:process_id_struct, process_id_struct)
      |> Map.put(:process_id_structs, process_id_structs)
    {:reply, {process_id_structs, process_id_struct}, new_state}
  end

  @impl true
  def handle_call({:save_system_id, system_id}, _from, state) do
    Logger.info("PROCESS_MEMORY: SAVE_SYSTEM_ID")
    new_state = state
      |> Map.put(:system_id, system_id)
    {:reply, system_id, new_state}
  end

  @impl true
  def handle_call({:save_readlist_entries, read_list}, _from, state) do
    Logger.info("PROCESS_MEMORY: SAVE_READLIST_ENTRY")
    new_state = state
      |> Map.put(:read_list, read_list)
    {:reply, read_list, new_state}
  end

  @impl true
  def handle_call({:save_new_timestamp_rank_pair, pair}, _from, state) do
    Logger.info("PROCESS_MEMORY: SAVE_NEW_TIMESTAMP_RANK_PAIR")
    new_state = state
      |> Map.put(:timestamp_rank_pair, pair)
    {:reply, pair, new_state}
  end

  @impl true
  def handle_call(:reset_ack_counter, _from, state) do
    Logger.info("PROCESS_MEMORY: RESET_ACK_COUNTER")
    new_state = state
      |> Map.put(:acknowledgments, 0)
    {:reply, 0, new_state}
  end

  @impl true
  def handle_call({:save_register_value, register, value}, _from, state) do
    Logger.info("PROCESS_MEMORY: SAVE_REGISTER_VALUE")
    updated_registers = Map.put(state.registers, register, value)
    new_state = state
      |> Map.put(:registers, updated_registers)
    {:reply, {register, value}, new_state}
  end

  @impl true
  def handle_call({:save_register_writer_data, request_id, value_to_be_written, register_to_be_written}, _from, state) do
    Logger.info("PROCESS_MEMORY: SAVE_REGISTER_WRITER_DATA")
    new_state = state
      |> Map.put(:request_id, request_id)
      |> Map.put(:value_to_be_written, value_to_be_written)
      |> Map.put(:register_to_be_written, register_to_be_written)
    {:reply, {request_id, value_to_be_written, register_to_be_written}, new_state}
  end

  @impl true
  def handle_call(:increment_ack_counter, _from, state) do
    Logger.info("PROCESS_MEMORY: INCREMENT_ACK_COUNTER")
    new_state = state
      |> Map.put(:acknowledgments, state.acknowledgments + 1)
    {:reply, state.acknowledgments + 1, new_state}
  end

  @impl true
  def handle_call({:update_reading_flag, value}, _from, state) do
    Logger.info("PROCESS_MEMORY: UPDATE_READING_FLAG")
    new_state = state
      |> Map.put(:reading, value)
    {:reply, new_state.reading, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    Logger.info("PROCESS_MEMORY: GET_STATE EVENT")
    {:reply, state, state}
  end

end
