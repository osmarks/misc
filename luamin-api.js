const express = require("express")
const luamin = require("luamin")

const app = express()

app.use(function(req, res, next) {
    var data = ''
    req.setEncoding('utf8')
    req.on('data', chunk => {
        data += chunk
    })
    req.on('end', () => {
        req.body = data
        next()
    })
});

app.post("*", (req, res) => {
    console.log("Input length:", req.body.length)
    try {
        const min = luamin.minify(req.body) 
        console.log("Output length:", min.length)
        res.send(min)
    } catch(e) {
        res.status(400).send(e.toString())
    }
    res.end()
})

app.listen(12432)