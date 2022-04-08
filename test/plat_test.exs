defmodule PlatTest do
  use ExUnit.Case
  doctest Plat

  test "greets the world" do
    assert Plat.hello() == :world
  end
end
