defmodule Plat.DataWorker do
  use GenServer

  alias Plat.{ProcessRegistry, Cell, ValStore}

  def start_link([store, worker_id]) do
    IO.puts("Starting Data worker #{worker_id}")

    GenServer.start_link(
      __MODULE__,
      store,
      name: via_tuple(worker_id)
    )
  end

  defp via_tuple(worker_id) do
    ProcessRegistry.via_tuple({__MODULE__, worker_id})
  end

  def put(worker_id, ref, cell_data) do
    GenServer.cast(via_tuple(worker_id), {:put, ref, cell_data})
  end

  def get(worker_id, ref) do
    GenServer.call(via_tuple(worker_id), {:get, ref})
  end

  def get(worker_id, ref, param, default) do
    GenServer.call(via_tuple(worker_id), {:get , ref, param, default})
  end

  def get_keys(worker_id) do
    GenServer.call(via_tuple(worker_id), {:get_keys})
  end

  def update(worker_id, ref, new_cell_data) do
    GenServer.cast(via_tuple(worker_id), {:update, ref, new_cell_data})
  end

  def update_key(worker_id, ref, key, default, update_fn) do
    GenServer.cast(via_tuple(worker_id), {:update_key, ref, key, default, update_fn})
  end

  def replace_key(worker_id, ref, key, new_val) do
    GenServer.cast(via_tuple(worker_id), {:replace_key, ref, key, new_val})
  end

  def inform_change(worker_id, to_ref) do
    GenServer.cast(via_tuple(worker_id), {:changed, to_ref})
  end

  @impl true
  def init(store) do
    {:ok, store}
  end

  @impl true
  def handle_cast({:put, ref, cell_data}, store) do
    Cachex.put(store, ref, cell_data)
    {:noreply, store}
  end

  @impl true
  def handle_cast({:changed, to_ref}, store) do
    {:ok, to_cell_data} = Cachex.get(store, to_ref)
    new_cell = Cell.eval(to_cell_data)
    handle_cast({:update, to_ref, new_cell}, store) # Since its the correct worker_id - directly use the function
  end

  def handle_cast({:update_key, ref, key, default, update_fn}, store) do
    {:ok, existing_cell} = Cachex.get(store, ref)
    new_cell = Cell.update(existing_cell, key, default, update_fn)
    handle_cast({:update, ref, new_cell}, store) # Since its the correct worker_id - directly use the function
  end

  @impl true
  def handle_cast({:replace_key, ref, key, new_val}, store) do
    {:ok, existing_cell_data} = Cachex.get(store, ref)
    new_cell_data = Map.replace(existing_cell_data, key, new_val)
    handle_cast({:update, ref, new_cell_data}, store) # Since its the correct worker_id - directly use the function
  end

  @impl true
  def handle_cast({:update, ref, new_cell_data}, store) do
    {:ok, existing_cell_data} = Cachex.get(store, ref)
    current_val = Cell.get(existing_cell_data, :val)
    current_deps = Cell.get(existing_cell_data, :dependents)

    Cachex.update(store, ref, new_cell_data)
    new_val = Cell.get(new_cell_data, :val)
    if current_val != new_val do
      Enum.each(current_deps, &(ValStore.send_change_info(&1)))
    end

    {:noreply, store}
  end

  @impl true
  def handle_call({:get, ref}, _from, store) do
    cell_data = case Cachex.get(store, ref) do
      {:ok, contents} -> contents
      _ -> nil
    end
    {:reply, cell_data, store}
  end

  @impl true
  def handle_call({:get, ref, param, default}, _from, store) do
    data = case Cachex.get(store, ref) do
      {:ok, nil} -> default
      {:ok, contents} -> Map.get(contents, param, default)
      _ -> default
    end
    {:reply, data, store}
  end

  @impl true
  def handle_call({:get_keys}, _from, store) do
    {:reply, Cachex.keys(store), store}
  end
end
