import Database = require("better-sqlite3")

import * as C from "./config"
import * as log from "./log"

export const DB = Database(C.get("db"))

const migrations = [
`
--whatever
`
]

const executeMigration = DB.transaction((i) => {
    const migration = migrations[i]
    DB.exec(migration)
    DB.pragma(`user_version = ${i + 1}`)
    log.info(`Migrated to schema ${i + 1}`)
})

const schemaVersion = DB.pragma("user_version", { simple: true })
if (schemaVersion < migrations.length) {
    log.info(`Migrating DB - schema ${schemaVersion} used, schema ${migrations.length} available`)
    for (let i = schemaVersion; i < migrations.length; i++) {
        executeMigration(i)
    }
}

DB.pragma("foreign_keys = 1")

const preparedStatements = new Map()

export const SQL = (strings, ...params) => {
    const sql = strings.join("?")
    let stmt
    const cachedValue = preparedStatements.get(sql)
    if (!cachedValue) {
        stmt = DB.prepare(sql)
        preparedStatements.set(sql, stmt)
    } else {
        stmt = cachedValue
    }
    return {
        get: () => stmt.get.apply(stmt, params),
        run: () => stmt.run.apply(stmt, params),
        all: () => stmt.all.apply(stmt, params),
        statement: stmt
    }
}