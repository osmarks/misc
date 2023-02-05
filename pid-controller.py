import time
import collections

PIDState = collections.namedtuple("PIDState", ["Kp", "Ki", "Kd", "last_time", "integral", "last_error"])

def init(Kp, Ki, Kd): return PIDState(Kp, Ki, Kd, None, 0, None)
def step(state, error, deriv, ts=None):
    ts = ts if ts is not None else time.time()
    integral = state.integral
    if state.last_time:
        tdiff = ts - state.last_time
        integral += 0.5 * (state.last_error + error) * tdiff # approximate actually integrating using a trapzeium
    output = state.Kp * error + state.Ki * integral + state.Kd * deriv
    return PIDState(Kp=state.Kp, Ki=state.Ki, Kd=state.Kd, last_time=ts, integral=integral, last_error=error), output

if __name__ == "__main__":
    import matplotlib.pyplot as plt, numpy as np
    def extract_series(l, ix): return list(map(lambda x: x[ix], l))
    values = [(10, -10, 0, 0, 0)]
    state = init(10, 4, -0.3)
    setpoint = -5
    max_time = 2
    timestep = 0.05
    times = np.arange(0, max_time, timestep)
    for t in times:
        current_pv = values[-1][0]
        error = setpoint - current_pv
        deriv = (error - (state.last_error or 0)) / timestep
        state, output = step(state, error, deriv, ts=t)
        output = max(min(output, 10), -10)
        print(output, current_pv, error)
        new_pv = current_pv + (output + 1) * 0.05
        values.append((new_pv, error, output, state.integral, deriv))
    #print(values)
    values = values[1:]
    plt.axis([0, max_time, -10, 10])
    plt.plot(times, extract_series(values, 0), label="PV")
    plt.plot(times, extract_series(values, 1), label="error")
    plt.plot(times, extract_series(values, 2), label="output")
    plt.plot(times, extract_series(values, 3), label="integ")
    plt.plot(times, extract_series(values, 4), label="deriv")
    plt.legend()
    plt.show()