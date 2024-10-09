# refer to https://sensirion.com/media/documents/48C4B7FB/64C134E7/Sensirion_SCD4x_Datasheet.pdf

import smbus3
import struct
import time
from prometheus_client import start_http_server, Gauge
import sys

location = sys.argv[1]

def sensiron_bad_crc8(data):
    crc = 0xFF
    POLY = 0x31
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 0x80:
                crc = (crc << 1) ^ POLY
            else:
                crc = (crc << 1)
        crc &= 0xFF
    return crc

bus = smbus3.SMBus(1)
ADDR = 0x62

def encode_word_crc(hi, lo):
    return [hi, lo, sensiron_bad_crc8([hi, lo])]

def setup():
    stop_measurement = smbus3.i2c_msg.write(ADDR, [0x3f, 0x86])
    bus.i2c_rdwr(stop_measurement)
    time.sleep(0.5)

    serial_cmd = smbus3.i2c_msg.write(ADDR, [0x36, 0x82]) # serial number
    serial_read = smbus3.i2c_msg.read(ADDR, 9)
    bus.i2c_rdwr(serial_cmd, serial_read)
    serial = bytes(serial_read)
    print((serial[0:2] + serial[3:5] + serial[6:8]).hex())
    time.sleep(0.1)
    # automatic self-calibration breaks badly if CO2 never below 400ppm, which is not guaranteed
    disable_asc = smbus3.i2c_msg.write(ADDR, [0x24, 0x16] + encode_word_crc(0x00, 0x00))
    bus.i2c_rdwr(disable_asc)
    time.sleep(0.1)

    # default offset of 4 degrees C is "probably right" but I don't have the equipment to test this
    #real_offset = 4.0
    #offset_bytes = struct.pack(">H", int(real_offset * 65535.0 / 175.0))
    #set_temp_offset = smbus3.i2c_msg.write(ADDR, [0x24, 0x1d] + encode_word_crc(*offset_bytes))
    #bus.i2c_rdwr(set_temp_offset)
    #time.sleep(0.1)

    start_measurement = smbus3.i2c_msg.write(ADDR, [0x21, 0xb1])
    bus.i2c_rdwr(start_measurement)

setup()

temperature = Gauge("scd4x_temperature", "Temperature in Celsius", ("location",))
co2_ppm = Gauge("scd4x_co2_ppm", "CO2 parts per million", ("location",))
rh = Gauge("scd4x_relative_humidity_percent", "Relative humidity in percent", ("location",))

def read_temperature_pressure():
    measurement_read_write = smbus3.i2c_msg.write(ADDR, [0xec, 0x05])
    measurement_read_read = smbus3.i2c_msg.read(ADDR, 9)
    bus.i2c_rdwr(measurement_read_write, measurement_read_read)
    measurement_read_read = bytes(measurement_read_read)

    print(measurement_read_read)

    co2 = struct.unpack(">H", measurement_read_read[0:2])[0]
    raw_temperature = struct.unpack(">H", measurement_read_read[3:5])[0]
    raw_humidity = struct.unpack(">H", measurement_read_read[6:8])[0]

    temperature_celsius = -45 + 175 * (raw_temperature / 65535.0)
    relative_humidity = raw_humidity / 65535.0 * 100

    temperature.labels(location=location).set(temperature_celsius)
    rh.labels(location=location).set(relative_humidity)
    co2_ppm.labels(location=location).set(co2)

start_http_server(9091)

while True:
    time.sleep(5)
    read_temperature_pressure()