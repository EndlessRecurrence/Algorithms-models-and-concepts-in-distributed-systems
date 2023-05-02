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
  def handle_cast({:save_process_id_structs, process_id_structs, process_id_struct}, state) do
    Logger.info("PROCESS_MEMORY: SAVE_PROCESS_ID_STRUCTS")
    new_state = state
      |> Map.put(:process_id_struct, process_id_struct)
      |> Map.put(:process_id_structs, process_id_structs)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:save_system_id, system_id}, state) do
    Logger.info("PROCESS_MEMORY: SAVE_SYSTEM_ID")
    new_state = state
      |> Map.put(:system_id, system_id)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:save_register_writer_data, request_id, value_to_be_written, register_to_be_written}, state) do
    Logger.info("PROCESS_MEMORY: SAVE_REGISTER_WRITER_DATA")
    new_state = state
      |> Map.put(:request_id, request_id)
      |> Map.put(:value_to_be_written, value_to_be_written)
      |> Map.put(:register_to_be_written, register_to_be_written)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast({:save_readlist_entries, read_list}, state) do
    Logger.info("PROCESS_MEMORY: SAVE_READLIST_ENTRY")
    new_state = state
      |> Map.put(:read_list, read_list)
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    Logger.info("PROCESS_MEMORY: GET_STATE EVENT")
    {:reply, state, state}
  end

end
