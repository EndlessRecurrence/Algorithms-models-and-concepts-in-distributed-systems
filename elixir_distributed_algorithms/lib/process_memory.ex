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
  def handle_call(:get_state, _from, state) do
    Logger.info("PROCESS_MEMORY: GET_STATE EVENT")
    {:reply, state, state}
  end

end
