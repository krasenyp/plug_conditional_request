defmodule Plug.ConditionalRequestTest do
  use ExUnit.Case

  doctest Plug.ConditionalRequest

  test "greets the world" do
    assert Plug.ConditionalRequest.hello() == :world
  end
end
