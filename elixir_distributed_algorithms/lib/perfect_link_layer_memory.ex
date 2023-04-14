defmodule DistributedAlgorithmsApp.PerfectLinkLayerMemory do
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
    Logger.info("PERFECT_LINK_LAYER_MEMORY: SAVE_PROCESS_ID_STRUCTS")
    new_state = state
      |> Map.put(:process_id_struct, process_id_struct)
      |> Map.put(:process_id_structs, process_id_structs)
    {:noreply, new_state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    Logger.info("PERFECT_LINK_LAYER_MEMORY: GET_STATE EVENT")
    {:reply, state, state}
  end

end
