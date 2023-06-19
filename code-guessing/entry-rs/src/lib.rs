
use pyo3::prelude::*;

mod entry_impl;
use entry_impl::entry;

#[pyfunction]
fn wrapped_entry(s: &str) -> PyResult<i32> {
    Ok(entry(s))
}

#[pymodule]
fn entry_rs(_py: Python, m: &PyModule) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(wrapped_entry, m)?)?;
    Ok(())
}
