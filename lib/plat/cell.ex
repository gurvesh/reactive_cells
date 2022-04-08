defmodule Plat.Cell do
  @enforce_keys [:name, :val, :dependents]

  alias Plat.{Cell, ValStore}

  defstruct [:name, :val, :formula, :formula_type, :var_list, :dependents]

  def new_default_cell([name: name]) do
    %Cell{
      name: name,
      val: 0,
      dependents: MapSet.new()
    }
  end

  def get_args(var_list) do
    Enum.map(
      var_list,
      fn ref -> ValStore.get_param(ref, :val, 0) end
    )
  end

  def get_var_vals(var_list) do
    for x <- var_list do
      {x, ValStore.get_param(x, :val, 0)}
    end
  end

  def get(%Cell{} = cell, key), do: Map.get(cell, key)

  def update(%Cell{} = cell, key, default, update_fn) do
    Map.update(cell, key, default, update_fn)
  end

  def eval(%Cell{formula_type: :excel} = cell) do
    {:module, modname} = cell.formula
    var_map = get_var_vals(cell.var_list)
    new_val = apply(modname, :run, [var_map])
    %Cell{cell | val: new_val}
  end

  def eval(%Cell{} = cell) do
    args = get_args(cell.var_list)
    new_val = apply(cell.formula, args)
    %Cell{cell | val: new_val}
  end

  def put_formula(%Cell{} = cell, quoted_formula, :excel) do
    var_list = Formular.used_vars(quoted_formula)
    mod_name =
      cell.name
      |> Atom.to_string
      |> String.upcase
      |> String.to_atom
    new_module = Formular.compile_to_module!(quoted_formula, mod_name)
    cell_data = %Cell{
      cell |
      formula: new_module,
      formula_type: :excel,
      var_list: var_list
      }
      |> eval
    ValStore.put(cell.name, cell_data)
    ValStore.register_deps(cell.name, var_list)
  end

  def put_formula(%Cell{} = cell, formula, var_list, :elixir) do
    cell_data = %Cell{
      cell |
      formula: formula,
      formula_type: :elixir,
      var_list: var_list
      }
      |> eval
    ValStore.put(cell.name, cell_data)
    ValStore.register_deps(cell.name, var_list)
  end
end
