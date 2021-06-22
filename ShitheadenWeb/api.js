document.addEventListener('alpine:init', () => {
    Alpine.data('game', () => ({
        snapshot: null,
        wsconnection: null,
        init() {
            this.wsconnection = new WebSocket("ws://localhost:3338/websocket");
            this.wsconnection.onmessage = (msg) => this.onmessage(msg);
        },
        async onmessage(msg) {
            const data = JSON.parse(await msg.data.text());

            if (data.requestMultiplayerChoice != undefined) {
                this.send(JSON.stringify({ singlePlayer: {}}));
            }

            if (data.multiplayerEvent != null) {
                this.snapshot = data.multiplayerEvent.multiplayerEvent.gameSnapshot.snapshot;
            }
        },
        send(message) {
            this.wsconnection.send(message);
        }
    }))
});