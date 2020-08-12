package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"
	"net/http"
)

func main() {
	cleanup()

	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	go func() {
		sigch := make(chan os.Signal, 1)
		defer signal.Stop(sigch)

		signal.Notify(sigch, syscall.SIGINT, syscall.SIGTERM)

		select {
		case sig := <-sigch:
			log.Println(sig, "- cleaning up")
		case <-ctx.Done():
		}

		cancel()
	}()

	buffer := &dataBuffer{
		queue: make([]string, 0, maxQueuedLines),
	}

	ch := make(chan string)
	go dwarfFortress(ctx, buffer, ch)

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		select {
		case <-r.Context().Done():
			// Client went away before a message was available.
		case line := <-ch:
			// Abuse http.Error to just write a textual response.
			http.Error(w, line, http.StatusOK)
		}
	})
	http.ListenAndServe(":1556", nil)
}