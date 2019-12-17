defmodule CQL.DataTypesTest do
  use ExUnit.Case
  use ExCheck

  import CQL.DataTypes

  property "ascii" do
    for_all bin in binary() do
      bin == bin |> encode(:ascii) |> drop_size |> decode(:ascii)
    end
  end

  property "bigint" do
    for_all n in int() do
      n == n |> encode(:bigint) |> has_size(8) |> decode(:bigint)
    end
  end

  property "blob" do
    for_all bin in binary() do
      bin == bin |> encode(:blob) |> drop_size |> decode(:blob)
    end
  end

  test "blob terms" do
    terms = [
      nil,
      100,
      100.001,
      [1, 2, 3],
      %{a: 1, b: 2, c: "last"},
      true
    ]

    for term <- terms do
      assert term == term |> encode(:blob) |> drop_size |> decode(:blob)
    end
  end

  property "boolean" do
    for_all b in bool() do
      b == b |> encode(:boolean) |> has_size(1) |> decode(:boolean)
    end
  end

  property "counter" do
    for_all n in int() do
      n == n |> encode(:counter) |> has_size(8) |> decode(:counter)
    end
  end

  test "date" do
    date = DateTime.utc_now() |> DateTime.to_date()
    assert date == date |> encode(:date) |> drop_size |> decode(:date)
  end

  test "time" do
    time = DateTime.utc_now() |> DateTime.to_time()
    assert time == time |> encode(:time) |> drop_size |> decode(:time)

    time = ~T[01:20:59.999999]
    assert time == time |> encode(:time) |> drop_size |> decode(:time)

    time = ~T[01:20:33.567890]
    assert time == time |> encode(:time) |> drop_size |> decode(:time)
  end

  test "timestamp with naive time" do
    time = ~N[2016-02-03 04:05:06.007]
    assert time == time |> encode(:timestamp) |> drop_size |> decode(:timestamp)
  end

  test "timestamp with DateTime" do
    time = DateTime.utc_now()

    naive =
      time
      |> DateTime.to_naive()
      |> Map.update!(:microsecond, fn {n, 6} -> {div(n, 1000) * 1000, 3} end)

    assert naive == time |> encode(:timestamp) |> drop_size |> decode(:timestamp)
  end

  test "decimal" do
    xs = [
      {111_222_333_444_555_666_777_888_999_000, 30},
      {-100_200_300_400_500_600_700_800_900, 89},
      {9_374_756_681_239_761_865_712_657_819_245, 98}
    ]

    for x <- xs do
      assert x == x |> encode(:decimal) |> drop_size |> decode(:decimal)
    end
  end

  property "decimal" do
    for_all x in {pos_integer(), int()} do
      x == x |> encode(:decimal) |> drop_size |> decode(:decimal)
    end
  end

  test "double" do
    xs = [
      1.2345,
      0.987654321,
      -23.591
    ]

    for x <- xs do
      assert x == x |> encode(:double) |> has_size(8) |> decode(:double)
    end
  end

  test "float" do
    xs = [
      1.235,
      0.981,
      -23.590
    ]

    for x <- xs do
      assert trunc(x * 1000) ==
               x |> encode(:float) |> has_size(4) |> decode(:float) |> Kernel.*(1000) |> trunc
    end
  end

  test "inet" do
    nets = [
      {127, 0, 0, 1},
      {192, 168, 100, 102}
    ]

    for net <- nets do
      assert net == net |> encode(:inet) |> has_size(4) |> decode(:inet)
    end
  end

  test "inet v6" do
    nets = [
      {0, 0, 0, 0, 0, 0, 0, 1}
    ]

    for net <- nets do
      assert net == net |> encode(:inet) |> has_size(16) |> decode(:inet)
    end
  end

  property "int" do
    for_all n in int() do
      n == n |> encode(:int) |> has_size(4) |> decode(:int)
    end
  end

  test "list" do
    lists = [
      {:int, [10, 20, 30]},
      {:text, ["name", "example", "sample"]}
    ]

    for {type, list} <- lists do
      assert list == list |> encode({:list, type}) |> drop_size |> decode({:list, type})
    end
  end

  test "map" do
    maps = [
      {{:text, :int}, %{"a" => 10, "b" => 20, "c" => 30}},
      {{:text, :text}, %{"aaa" => "name", "bbb" => "example", "ccc" => "sample"}},
      {{:int, :double}, %{1 => 11.1, 10 => 22.2, 100 => 33.3}}
    ]

    for {type, map} <- maps do
      assert map == map |> encode({:map, type}) |> drop_size |> decode({:map, type})
    end

    map = %{a: 10, b: 20, c: 30}
    [{type, expected} | _] = maps
    assert expected == map |> encode({:map, type}) |> drop_size |> decode({:map, type})
  end

  test "tuple" do
    types = [:int, :double, :text, :int, :float]
    tuple = {123, 23.983, "Test", 91, 1.0}
    assert tuple == tuple |> encode({:tuple, types}) |> drop_size |> decode({:tuple, types})
  end

  test "varint" do
    xs = [
      9_988_776_655_443_322_110_987_654_321,
      -19_477_209_892_471_957_969_713_409_154_091_853,
      89_769_087_908_775_467_436_532_432,
      1_000_000_000_000_000_000_000_000_000
    ]

    for x <- xs do
      assert x == x |> encode(:varint) |> drop_size |> decode(:varint)
    end
  end

  test "uuid" do
    uuids = [UUID.uuid1(), UUID.uuid4()]

    for uuid <- uuids do
      assert uuid == uuid |> encode(:uuid) |> drop_size |> decode(:uuid)
    end

    assert %CQL.Error{code: :invalid, info: info} = encode("bad id", :uuid)
    assert info =~ "Expected a 'uuid'"
  end

  defp drop_size(<<_::integer-32, rest::bytes>>), do: rest

  defp has_size(buffer, size) do
    <<n::integer-32, value::bytes>> = buffer

    if n == size do
      value
    else
      buffer
    end
  end
end
