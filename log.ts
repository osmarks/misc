import chalk from "chalk"
import { format } from "date-fns"

const rawLog = (level, main) => {
    const timestamp = format(new Date(), "HH:mm:ss")
    console.log(chalk`{bold ${timestamp}} ${level} ${main}`)
}

export const info = x => rawLog(chalk.black.bgBlueBright("INFO"), x)
export const warning = x => rawLog(chalk.black.bgKeyword("orange")("WARN"), x)
export const error = x => rawLog(chalk.black.bgRedBright("FAIL"), x)