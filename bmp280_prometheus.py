import smbus
import struct
import time
from prometheus_client import start_http_server, Gauge
import sys

location = sys.argv[1]

bus = smbus.SMBus(1)
ADDR = 0x76
ID_REGISTER = 0xD0
TARGET_ID = 0x58
CTRL_MEAS_REGISTER = 0xF4
PRESSURE_REGISTER_BASE = 0xF7
TEMP_REGISTER_BASE = 0xFA
CALIBRATION_VALUES = {
    "dig_T1": {"address": (0x88, 0x89), "unpack": "<H"},
    "dig_T2": {"address": (0x8A, 0x8B), "unpack": "<h"},
    "dig_T3": {"address": (0x8C, 0x8D), "unpack": "<h"},
    "dig_P1": {"address": (0x8E, 0x8F), "unpack": "<H"},
    "dig_P2": {"address": (0x90, 0x91), "unpack": "<h"},
    "dig_P3": {"address": (0x92, 0x93), "unpack": "<h"},
    "dig_P4": {"address": (0x94, 0x95), "unpack": "<h"},
    "dig_P5": {"address": (0x96, 0x97), "unpack": "<h"},
    "dig_P6": {"address": (0x98, 0x99), "unpack": "<h"},
    "dig_P7": {"address": (0x9A, 0x9B), "unpack": "<h"},
    "dig_P8": {"address": (0x9C, 0x9D), "unpack": "<h"},
    "dig_P9": {"address": (0x9E, 0x9F), "unpack": "<h"}
}

def setup():
    assert bus.read_byte_data(ADDR, ID_REGISTER) == TARGET_ID
    bus.write_byte_data(ADDR, CTRL_MEAS_REGISTER, 0b101_101_11) # max oversampling mode (we don"t really care about power), power on
    calibration = {}
    for key, value in CALIBRATION_VALUES.items():
        calibration[key] = struct.unpack(value["unpack"], bytes([bus.read_byte_data(ADDR, value["address"][0]), bus.read_byte_data(ADDR, value["address"][1])]))[0]
    return calibration

def read_raw_adc(base):
    msb, lsb, xlsb = bus.read_i2c_block_data(ADDR, base, 3)
    return (msb << 16 | lsb << 8 | xlsb) >> 4

def bmp280_compensate_T_double(adc_T, dig_T1, dig_T2, dig_T3, **kwargs):
    var1 = (adc_T / 16384.0 - dig_T1 / 1024.0) * dig_T2
    var2 = ((adc_T / 131072.0 - dig_T1 / 8192.0) * 
            (adc_T / 131072.0 - dig_T1 / 8192.0)) * dig_T3
    t_fine = int(var1 + var2)
    T = (var1 + var2) / 5120.0
    return T, t_fine

def bmp280_compensate_P_double(adc_P, t_fine, dig_P1, dig_P2, dig_P3, dig_P4, dig_P5, dig_P6, dig_P7, dig_P8, dig_P9, **kwargs):
    var1 = t_fine / 2.0 - 64000.0
    var2 = var1 * var1 * dig_P6 / 32768.0
    var2 = var2 + var1 * dig_P5 * 2.0
    var2 = (var2 / 4.0) + (dig_P4 * 65536.0)
    var1 = (dig_P3 * var1 * var1 / 524288.0 + dig_P2 * var1) / 524288.0
    var1 = (1.0 + var1 / 32768.0) * dig_P1
    if var1 == 0.0:
        return 0  # avoid exception caused by division by zero
    p = 1048576.0 - adc_P
    p = (p - (var2 / 4096.0)) * 6250.0 / var1
    var1 = dig_P9 * p * p / 2147483648.0
    var2 = p * dig_P8 / 32768.0
    p = p + (var1 + var2 + dig_P7) / 16.0
    return p

calibration = setup()

temperature = Gauge("bmp280_temperature", "Temperature in Celsius", ("location",))
pressure = Gauge("bmp280_pressure", "Pressure in Pascals", ("location",))

def read_temperature_pressure():
    adc_T = read_raw_adc(TEMP_REGISTER_BASE)
    adc_P = read_raw_adc(PRESSURE_REGISTER_BASE)
    T, t_fine = bmp280_compensate_T_double(adc_T, **calibration)
    P = bmp280_compensate_P_double(adc_P, t_fine, **calibration)
    temperature.labels(location=location).set(T)
    pressure.labels(location=location).set(P)

start_http_server(9091)

while True:
    read_temperature_pressure()
    time.sleep(1)
