defmodule Plat.System do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def init(_init_arg) do
    Supervisor.init(
      [
        {Cachex, name: :val_cache},
        Plat.ProcessRegistry,
        {Plat.ValStore, cache: :val_cache}
      ],
      strategy: :one_for_one
    )
  end

end
