# Mastermind — Terminal Edition

This project is a **standalone Swift implementation** of the Mastermind game, designed to be played entirely in the terminal.  
It does not use the provided online API. Instead, the game generates a secret code locally (or allows another player to set the code), and players interact through a colorful, emoji-rich terminal interface.  
Features include hints, give-up option, attempt history, replay support, and polished ANSI-styled printing.

---

## API Analysis

The provided Mastermind API is minimal and easy to understand, offering only three main endpoints: `/game` to create or delete a game, and `/guess` to submit a guess. This simplicity is useful for a lightweight client, but it limits the richness of the interaction. For example, the server does not provide stateful information such as the number of attempts, elapsed time, or the history of guesses, which means all of this must be tracked client-side.

To improve the API, it would be helpful to add a `/status` endpoint that returns the current state of the game, including the number of attempts, history of guesses, and whether the game has been won or lost. Additionally, including metadata such as the game creation time and optional difficulty settings (like code length or digit range) would make the API more flexible and closer to the full Mastermind experience.

If redesigning the API from scratch, I would also introduce optional authentication or session tokens so that multiple users could play independently without collisions. Furthermore, adding a `/restart` endpoint or a way to configure new game settings directly through the API would reduce the need for clients to manage this logic themselves. These changes would make the API more complete and user-friendly while preserving its current simplicity.
