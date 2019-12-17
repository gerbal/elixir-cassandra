defmodule Cassandra.Cluster.Schema.Partitioner.Murmur3Test do
  use ExUnit.Case, async: true

  alias Cassandra.Cluster.Schema.Partitioner.Murmur3

  test "#create_token" do
    tests = [
      {"123", -7_468_325_962_851_647_638},
      {String.duplicate("\x00\xff\x10\xfa\x99", 10), 5_837_342_703_291_459_765},
      {String.duplicate("\xfe", 8), -8_927_430_733_708_461_935},
      {String.duplicate("\x10", 8), 1_446_172_840_243_228_796},
      {"9223372036854775807", 7_162_290_910_810_015_547}
    ]

    for {parition_key, token} <- tests do
      assert token == Murmur3.create_token(parition_key)
    end
  end

  test "#parse_token" do
    tests = [
      {"-7468325962851647638", -7_468_325_962_851_647_638},
      {"5837342703291459765", 5_837_342_703_291_459_765},
      {"-8927430733708461935", -8_927_430_733_708_461_935},
      {"1446172840243228796", 1_446_172_840_243_228_796},
      {"7162290910810015547", 7_162_290_910_810_015_547}
    ]

    for {string, token} <- tests do
      assert token == Murmur3.parse_token(string)
    end
  end
end
