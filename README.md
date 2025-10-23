# MermaidLive SSR

A server-side rendering application for Mermaid diagrams.

## Project Structure

This repository contains the MermaidLive SSR application in the `mermaidlive_ssr/` subdirectory.

## Development

To work with this project:

1. Navigate to the project directory:
   ```bash
   cd mermaidlive_ssr
   ```

2. Follow the instructions in the project README:
   ```bash
   mix setup
   mix phx.server
   ```

## Docker

To run with Docker Compose:

```bash
docker-compose up --build
```

## CI/CD

The GitHub Actions workflow automatically handles the subdirectory structure and runs all mix commands from the correct location.

## Scripts

- `scripts/pre-render-svg` - Pre-renders SVG diagrams (automatically navigates to the correct directory)
- `mermaidlive_ssr/mix_release.sh` - Builds production release (run from project root)
