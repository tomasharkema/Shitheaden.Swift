const express = require("express");
const fs = require("fs");
const http = require("http");
const net = require("net");
var utf8 = require("utf8");
const app = express();

var serverPort = 8080;

var server = http.createServer(app);

//set the template engine ejs
app.set("view engine", "ejs");

//middlewares
app.use(express.static("public"));

//routes
app.get("/", (req, res) => {
  res.render("index");
});

server.listen(serverPort);

//socket.io instantiation
const io = require("socket.io")(server);

//Socket Connection

io.on("connection", function (socket) {
  const port = 3333;
  const host = "shitheaden";

  const telnet = net.createConnection(
    {
      port,
      host,
    },
    () => {
      this.state = "start";
    }
  );

  telnet.on("error", (error) => {
    console.log("ERROR", error);
  });

  socket.on("error", (error) => {
    console.log("ERROR", error);
    socket.disconnect();
  });
  telnet.on("end", () => {
    console.log("END");
  });

  telnet.on("close", () => {
    console.log("close");
    socket.disconnect();
  });

  telnet.on("connect", () => {
    console.log("connected");
  });

  socket.on("data", function (data) {
    telnet.write(data);
    socket.emit("data", data);
  });
  telnet.on("data", function (d) {
    socket.emit("data", utf8.decode(d.toString("binary")));
  });
  socket.on("disconnect", function () {
    console.log("END");
    telnet.end();
  });
});
