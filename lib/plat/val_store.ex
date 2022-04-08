defmodule Plat.ValStore do
  ## Keep a local Cachex kv-store. On change of any value / new value added,
  ## send a message to all the :deps cells with the {:name, :val} format

  use Supervisor

  @folder "./persist"
  @worker_count 10

  alias Plat.{DataWorker, Cell}

  def start_link([cache: cache_name]) do
    IO.puts("Starting Valstore supervisor")
    Supervisor.start_link(__MODULE__, cache_name, name: __MODULE__)
  end

  @impl true
  def init(cache_name) do
    children = Enum.map(1..@worker_count, fn id -> worker_spec(cache_name, id) end)
    Supervisor.init(children, strategy: :one_for_one)
  end

  defp worker_spec(cache_name, worker_id) do
    default_worker_spec = DataWorker.child_spec([cache_name, worker_id])
    %{default_worker_spec | id: worker_id}
  end

  def child_spec([cache: cache_name]) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [[cache: cache_name]]},
      type: :supervisor
    }
  end

  defp choose_worker(key) do
    :erlang.phash2(key, @worker_count) + 1
  end

  def put(ref, cell_data) do
    ref
    |> choose_worker()
    |> DataWorker.put(ref, cell_data)
  end

  def update(ref, new_cell_data) do
    ref
    |> choose_worker()
    |> DataWorker.update(ref, new_cell_data)
  end

  def update_key(ref, key, default, update_fn) do
    ref
    |> choose_worker()
    |> DataWorker.update_key(ref, key, default, update_fn)
  end

  def replace_key(ref, key, new_val) do
    ref
    |> choose_worker()
    |> DataWorker.replace_key(ref, key, new_val)
  end

  def get(ref) do
    ref
    |> choose_worker()
    |> DataWorker.get(ref)
  end

  @spec get_param(any, any, any) :: any
  def get_param(ref, param, default) do
    ref
    |> choose_worker()
    |> DataWorker.get(ref, param, default)
  end

  def send_change_info(to_ref) do
    to_ref
    |> choose_worker()
    |> DataWorker.inform_change(to_ref)
  end

  def register_deps(ref, var_list) do
    {:ok, current_cells} = get_keys()
    Enum.each(
      var_list,
      fn var ->
        ## First check if it is present in the cache,
        ## and if not - add a default cell
        if (var in current_cells) do
          update_key(
              var,
              :dependents,
              MapSet.new([ref]), ## Default value
              fn dependents -> MapSet.put(dependents, ref) end
            )
        else
            put(
              var,
              %Cell{
                name: var,
                val: 0,
                dependents: MapSet.new([ref])
              }
            )
        end
      end
    )
  end

  def get_keys do
    "get_some_keys"
    |> choose_worker()
    |> DataWorker.get_keys()
  end
end
