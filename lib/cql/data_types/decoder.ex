defmodule CQL.DataTypes.Decoder do
  @moduledoc false

  require Bitwise
  require Logger

  def decode({type, buffer}), do: decode(buffer, type)
  def decode(buffer, type) do
    {value, ""} = dec(buffer, type)
    value
  end

  def byte(<<n::8, rest::bytes>>) do
    {n, rest}
  end

  def boolean(<<0::8, rest::bytes>>), do: {false, rest}
  def boolean(<<_::8, rest::bytes>>), do: {true, rest}

  def tinyint(<<n::signed-integer-8, rest::bytes>>) do
    {n, rest}
  end

  def short(<<n::integer-16, rest::bytes>>) do
    {n, rest}
  end

  def int(<<n::signed-integer-32, rest::bytes>>) do
    {n, rest}
  end

  def long(<<n::signed-integer-64, rest::bytes>>) do
    {n, rest}
  end

  def float(<<x::float-32, rest::bytes>>) do
    {x, rest}
  end

  def double(<<x::float-64, rest::bytes>>) do
    {x, rest}
  end

  def string({len, buffer}) do
    <<str::bytes-size(len), rest::bytes>> = buffer
    {str, rest}
  end

  def string(buffer) do
    buffer |> short |> string
  end

  def long_string(buffer) do
    buffer |> int |> string
  end

  def uuid(<<uuid::bits-128, rest::bytes>>) do
    {UUID.binary_to_string!(uuid), rest}
  end

  def string_list({n, buffer}) do
    ntimes(n, :string, buffer)
  end

  def string_list(buffer) do
    buffer |> short |> string_list
  end

  def bytes({len, buffer}) when is_integer(len) and len < 0 do
    {nil, buffer}
  end

  def bytes({len, buffer}) do
    <<str::bytes-size(len), rest::bytes>> = buffer
    {str, rest}
  end

  def bytes(buffer) do
    buffer |> int |> bytes
  end

  def short_bytes(buffer) do
    buffer |> short |> bytes
  end

  def inet(<<a, b, c, d>>) do
    {{a, b, c, d}, ""}
  end

  def inet(
      <<a::integer-16,
      b::integer-16,
      c::integer-16,
      d::integer-16,
      e::integer-16,
      f::integer-16,
      g::integer-16,
      h::integer-16>>
    ) do
    {{a, b, c, d, e, f, g, h}, ""}
  end

  def inet(<<size, data::size(size)-bytes, buffer::bits>>) do
    {ip, _} = inet(data)
    {port, buffer} = int(buffer)
    {{ip, port}, buffer}
  end

  def string_map({n, buffer}) do
    key_value = fn buf ->
      {key, buf} = string(buf)
      {val, buf} = string(buf)
      {{key, val}, buf}
    end
    ntimes(n, key_value, buffer)
  end

  def string_map(buffer) do
    buffer |> short |> string_map
  end

  def string_multimap({n, buffer}) do
    key_value = fn buf ->
      {key, buf} = string(buf)
      {val, buf} = string_list(buf)
      {{key, val}, buf}
    end
    ntimes(n, key_value, buffer)
  end

  def string_multimap(buffer) do
    buffer |> short |> string_multimap
  end

  def bytes_map({n, buffer}) do
    key_value = fn buf ->
      {key, buf} = string(buf)
      {val, buf} = bytes(buf)
      {{key, val}, buf}
    end
    ntimes(n, key_value, buffer)
  end

  def bytes_map(buffer) do
    buffer |> short |> bytes_map
  end

  def list(buffer, type) do
    {n, buffer} = int(buffer)
    {list, rest} = ntimes(n, :bytes, buffer)
    {Enum.map(list, &decode(&1, type)), rest}
  end

  def map(buffer, {ktype, vtype}) do
    {n, buffer} = int(buffer)
    {list, rest} = ntimes(2 * n, :bytes, buffer)
    map =
      list
      |> Enum.chunk_every(2)
      |> Enum.map(fn [k, v] -> {decode(k, ktype), decode(v, vtype)} end)
      |> Enum.into(%{})
    {map, rest}
  end

  def set(buffer, type) do
    {list, buffer} = list(buffer, type)
    {MapSet.new(list), buffer}
  end

  def tuple(buffer, types) do
    {n, buffer} = short(buffer)
    {list, rest} = ntimes(n, :bytes, buffer)
    tuple =
      list
      |> Enum.zip(types)
      |> Enum.map(fn {buf, t} -> decode(buf, t) end)
      |> List.to_tuple

    {tuple, rest}
  end

  def varint({size, buffer}) do
    size = size * 8
    <<n::signed-integer-size(size), rest::bytes>> = buffer
    {n, rest}
  end

  def varint(buffer) do
    buffer |> int |> varint
  end

  def decimal(buffer) do
    {scale, buffer} = int(buffer)
    {unscaled, buffer} = varint(buffer)
    {{unscaled, scale}, buffer}
  end

  def blob(buffer) do
    try do
      term = :erlang.binary_to_term(buffer)
      {term, ""}
    rescue
      ArgumentError -> {buffer, ""}
    end
  end

  def date(buffer), do: CQL.DataTypes.Date.decode(buffer)
  def time(buffer), do: CQL.DataTypes.Time.decode(buffer)
  def timestamp(b), do: CQL.DataTypes.Timestamp.decode(b)

  def consistency(buffer) do
    {code, buffer} = short(buffer)
    {CQL.Consistency.name(code), buffer}
  end

  ### Helpers ###

  def flag?(flag, flags) do
    Bitwise.band(flag, flags) == flag
  end

  def flag_to_names(flag, flags) do
    flags
    |> Enum.filter(fn {_, code} -> Bitwise.band(flag, code) == code end)
    |> Enum.map(fn {name, _} -> name end)
  end

  def ntimes(n, func, buffer) do
    ntimes(n, func, buffer, [])
  end

  def ntimes(0, _, buffer, items) do
    {Enum.reverse(items), buffer}
  end

  def ntimes(n, func, buffer, items) do
    {item, buffer} = ap(func, buffer)
    ntimes(n - 1, func, buffer, [item | items])
  end

  def unpack(buffer, meta) do
    Enum.reduce(meta, {%{}, buffer}, &pick/2)
  end

  ### Utils ###

  defp pick({name, {func, key, predicate}}, {map, buffer}) do
    pick({name, {func, [when: predicate.(Map.get(map, key))]}}, {map, buffer})
  end

  defp pick({_, {_, [when: false]}}, {map, buffer}) do
    {map, buffer}
  end

  defp pick({name, {func, [when: true]}}, {map, buffer}) do
    pick({name, func}, {map, buffer})
  end

  defp pick({name, {func, [when: flag]}}, {map, buffer}) do
    pick({name, {func, [when: flag?(flag, map.flags)]}}, {map, buffer})
  end

  defp pick({name, {func, [unless: boolean]}}, {map, buffer}) when is_boolean(boolean) do
    pick({name, {func, [when: !boolean]}}, {map, buffer})
  end

  defp pick({name, func}, {map, buffer}) do
    {value, buffer} = ap(func, buffer)
    {Map.put(map, name, value), buffer}
  end

  defp ap(func, buffer) when is_atom(func) do
    apply(__MODULE__, func, [buffer])
  end

  defp ap(func, buffer) when is_function(func) do
    func.(buffer)
  end

  defp dec(nil,    _         ), do: {nil, ""}
  defp dec(buffer, :ascii    ), do: {buffer, ""}
  defp dec(buffer, :bigint   ), do: long(buffer)
  defp dec(buffer, :blob     ), do: blob(buffer)
  defp dec(buffer, :boolean  ), do: boolean(buffer)
  defp dec(buffer, :counter  ), do: long(buffer)
  defp dec(buffer, :date     ), do: date(buffer)
  defp dec(buffer, :decimal  ), do: decimal(buffer)
  defp dec(buffer, :double   ), do: double(buffer)
  defp dec(buffer, :float    ), do: float(buffer)
  defp dec(buffer, :inet     ), do: inet(buffer)
  defp dec(buffer, :int      ), do: int(buffer)
  defp dec(buffer, :smallint ), do: short(buffer)
  defp dec(buffer, :text     ), do: {buffer, ""}
  defp dec(buffer, :time     ), do: time(buffer)
  defp dec(buffer, :timestamp), do: timestamp(buffer)
  defp dec(buffer, :timeuuid ), do: uuid(buffer)
  defp dec(buffer, :tinyint  ), do: tinyint(buffer)
  defp dec(buffer, :uuid     ), do: uuid(buffer)
  defp dec(buffer, :varchar  ), do: {buffer, ""}
  defp dec(buffer, :varint   ), do: varint(buffer)

  defp dec(buffer, {:list, type}),   do: list(buffer, type)
  defp dec(buffer, {:map, type}),    do: map(buffer, type)
  defp dec(buffer, {:set, type}),    do: set(buffer, type)
  defp dec(buffer, {:tuple, types}), do: tuple(buffer, types)

  defp dec(_buffer, {_type, size}) when is_integer(size) and size < 0, do: nil
  defp dec(buffer, {type, _size}), do: dec(buffer, type)
end
