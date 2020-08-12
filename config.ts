import { parse } from "toml"
import { readFileSync } from "fs"
import { join } from "path"
import { path } from "ramda"

import * as log from "./log"

const defaults = {
    production: process.env.NODE_ENV === "production"
}

const config = parse(readFileSync(process.env.CONFIG_FILE || join(__dirname, "..", "config.toml"), { encoding: "utf8" }))

export const get = key => {
    const arrKey = key.split(".")
    const out = path(arrKey, config) || path(arrKey, defaults)
    if (out === undefined) {
        log.error(`Configuration parameter ${key} missing`)
        process.exit(1)
    }
    return out
}