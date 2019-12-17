defmodule Cassandra.Murmur3Test do
  use ExUnit.Case, async: true

  test "#x64_128" do
    tests = [
      {"123", -7_468_325_962_851_647_638},
      {String.duplicate("\x00\xff\x10\xfa\x99", 10), 5_837_342_703_291_459_765},
      {String.duplicate("\xfe", 8), -8_927_430_733_708_461_935},
      {String.duplicate("\x10", 8), 1_446_172_840_243_228_796},
      {"9223372036854775807", 7_162_290_910_810_015_547},
      {"\x01\x02\x03\x04\x05\x06\a\b\t\n\v\f\r\x0E\x0F\x10", -5_563_837_382_979_743_776},
      {"\x02\x03\x04\x05\x06\a\b\t\n\v\f\r\x0E\x0F\x10\x11", -1_513_403_162_740_402_161},
      {"\x03\x04\x05\x06\a\b\t\n\v\f\r\x0E\x0F\x10\x11\x12", -495_360_443_712_684_655},
      {"\x04\x05\x06\a\b\t\n\v\f\r\x0E\x0F\x10\x11\x12\x13", 1_734_091_135_765_407_943},
      {"\x05\x06\a\b\t\n\v\f\r\x0E\x0F\x10\x11\x12\x13\x14", -3_199_412_112_042_527_988},
      {"\x06\a\b\t\n\v\f\r\x0E\x0F\x10\x11\x12\x13\x14\x15", -6_316_563_938_475_080_831},
      {"\a\b\t\n\v\f\r\x0E\x0F\x10\x11\x12\x13\x14\x15\x16", 8_228_893_370_679_682_632},
      {"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
       5_457_549_051_747_178_710},
      {"\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF",
       -2_824_192_546_314_762_522},
      {"\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE",
       -833_317_529_301_936_754},
      {"\x00\x01\x02\x03\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF",
       6_463_632_673_159_404_390},
      {"\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE\xFE",
       -1_672_437_813_826_982_685},
      {"\xFE\xFE\xFE\xFE", 4_566_408_979_886_474_012},
      {"\x00\x00\x00\x00", -3_485_513_579_396_041_028},
      {"\x00\x01\x7F\x7F", 6_573_459_401_642_635_627},
      {"\x00\xFF\xFF\xFF", 123_573_637_386_978_882},
      {"\xFF\x01\x02\x03", -2_839_127_690_952_877_842},
      {"\x00\x01\x02\x03\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF",
       6_463_632_673_159_404_390},
      {"\xE2\xE7", -8_582_699_461_035_929_883},
      {"\xE2\xE7\xE2\xE7\xE2\xE7\x01", 2_222_373_981_930_033_306}
    ]

    for {string, hash} <- tests do
      assert hash == Cassandra.Murmur3.x64_128(string)
    end
  end
end
