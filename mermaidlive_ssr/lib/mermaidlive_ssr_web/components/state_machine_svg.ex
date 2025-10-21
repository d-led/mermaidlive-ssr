defmodule MermaidLiveSsrWeb.Components.StateMachineSvg do
  @moduledoc """
  A minimal SVG state machine LiveComponent that only updates the specific elements that change.

  Parameters:
  - state: "waiting" | "working" | "aborting"
  - counter: integer (optional, for note text)

  Updates are minimal - only changes the active state class and counter text.
  """
  use Phoenix.LiveComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div class="state-machine-svg">
      <svg aria-roledescription="stateDiagram" role="graphics-document document" viewBox="0 0 253.8984375 412" style="max-width: 253.898px; background-color: white;" class="statediagram" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns="http://www.w3.org/2000/svg" width="100%" id="my-svg">
        <style>
          #my-svg{font-family:"trebuchet ms",verdana,arial,sans-serif;font-size:16px;fill:#333;}
          #my-svg .inProgress>*{font-style:italic!important;stroke-dasharray:5 5!important;stroke-width:3px!important;}
          #my-svg .inProgress span{font-style:italic!important;stroke-dasharray:5 5!important;stroke-width:3px!important;}
          #my-svg .node rect{fill:#ECECFF;stroke:#9370DB;stroke-width:1px;}
          #my-svg .node circle.state-start{fill:#333333;stroke:#333333;}
          #my-svg .statediagram-note rect{fill:#fff5ad;stroke:#aaaa33;stroke-width:1px;}
        </style>

        <g>
          <defs>
            <marker orient="auto" markerUnits="userSpaceOnUse" markerHeight="14" markerWidth="20" refY="7" refX="19" id="my-svg_stateDiagram-barbEnd">
              <path d="M 19,7 L9,13 L14,7 L9,1 Z"/>
            </marker>
          </defs>

          <g class="root">
            <!-- Start node -->
            <g transform="translate(72.015625, 15)" id="state-root_start-0" class="node default">
              <circle height="14" width="14" r="7" class="state-start"/>
            </g>

            <!-- Waiting state -->
            <g transform="translate(72.015625, 92)" id="state-waiting-4" class={"node #{if @state == "waiting", do: "inProgress", else: ""} statediagram-state"}>
              <rect height="40" width="68.5625" y="-20" x="-34.28125" ry="5" rx="5" class="basic label-container"/>
              <g transform="translate(-26.28125, -12)" class="label">
                <rect/>
                <foreignObject height="24" width="52.5625">
                  <div style="display: table-cell; white-space: nowrap; line-height: 1.5; max-width: 200px; text-align: center;" xmlns="http://www.w3.org/1999/xhtml">
                    <span class="nodeLabel">
                      <p>waiting</p>
                    </span>
                  </div>
                </foreignObject>
              </g>
            </g>

            <!-- Working state -->
            <g transform="translate(147.5390625, 206)" id="state-working-5" class={"node #{if @state == "working", do: "inProgress", else: ""} statediagram-state"}>
              <rect height="40" width="72.90625" y="-20" x="-36.453125" ry="5" rx="5" class="basic label-container"/>
              <g transform="translate(-28.453125, -12)" class="label">
                <rect/>
                <foreignObject height="24" width="56.90625">
                  <div xmlns="http://www.w3.org/1999/xhtml" style="display: table-cell; white-space: nowrap; line-height: 1.5; max-width: 200px; text-align: center;">
                    <span class="nodeLabel">
                      <p>working</p>
                    </span>
                  </div>
                </foreignObject>
              </g>
            </g>

            <!-- Aborting state -->
            <g transform="translate(45.90625, 352)" id="state-aborting-4" class={"node #{if @state == "aborting", do: "inProgress", else: ""} statediagram-state"}>
              <rect height="40" width="75.8125" y="-20" x="-37.90625" ry="5" rx="5" class="basic label-container"/>
              <g transform="translate(-29.90625, -12)" class="label">
                <rect/>
                <foreignObject height="24" width="59.8125">
                  <div style="display: table-cell; white-space: nowrap; line-height: 1.5; max-width: 200px; text-align: center;" xmlns="http://www.w3.org/1999/xhtml">
                    <span class="nodeLabel">
                      <p>aborting</p>
                    </span>
                  </div>
                </foreignObject>
              </g>
            </g>

            <!-- Note (only shown for working state with counter > 0) -->
            <g transform="translate(186.9921875, 352)" id="state-working----note-5" class="node statediagram-note" style={"display: #{if @state == "working" and @counter > 0, do: "block", else: "none"}"}>
              <g class="basic label-container">
                <rect fill="#fff5ad" stroke="#aaaa33" stroke-width="1" height="54" width="47.8125" y="-27" x="-23.90625"/>
              </g>
              <g transform="translate(-8.90625, -12)" style="" class="label">
                <rect/>
                <foreignObject height="24" width="17.8125">
                  <div style="display: table-cell; white-space: nowrap; line-height: 1.5; max-width: 200px; text-align: center;" xmlns="http://www.w3.org/1999/xhtml">
                    <span class="nodeLabel">
                      <p><%= @counter %></p>
                    </span>
                  </div>
                </foreignObject>
              </g>
            </g>

            <!-- Edges -->
            <g class="edgePaths">
              <path marker-end="url(#my-svg_stateDiagram-barbEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid transition" d="M72.016,22L72.016,26.167C72.016,30.333,72.016,38.667,72.016,47C72.016,55.333,72.016,63.667,72.016,67.833L72.016,72"/>
              <path marker-end="url(#my-svg_stateDiagram-barbEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid transition" d="M104.988,112L115.155,118.167C125.322,124.333,145.655,136.667,153.826,149C161.996,161.333,158.004,173.667,156.008,179.833L154.012,186"/>
              <path marker-end="url(#my-svg_stateDiagram-barbEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid transition" d="M124.414,226L117.284,232.167C110.154,238.333,95.893,250.667,88.763,263C81.633,275.333,81.633,287.667,77.969,299.167C74.304,310.667,66.976,321.333,63.311,326.667L59.647,332"/>
              <path marker-end="url(#my-svg_stateDiagram-barbEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid transition" d="M121.04,186L112.869,179.833C104.698,173.667,88.357,161.333,80.186,149C72.016,136.667,72.016,124.333,72.016,118.167L72.016,112"/>
              <path marker-end="url(#my-svg_stateDiagram-barbEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid transition" d="M38.361,332L36.349,326.667C34.337,321.333,30.313,310.667,28.301,299.167C26.289,287.667,26.289,275.333,26.289,259.667C26.289,244,26.289,225,26.289,206C26.289,187,26.289,168,31.236,152.333C36.183,136.667,46.077,124.333,51.024,118.167L55.971,112"/>
              <path style={"fill:none; display: #{if @state == "working" and @counter > 0, do: "block", else: "none"}"} class="edge-thickness-normal edge-pattern-solid transition note-edge" d="M161.382,226L165.651,232.167C169.919,238.333,178.456,250.667,182.724,263C186.992,275.333,186.992,287.667,186.992,298C186.992,308.333,186.992,316.667,186.992,320.833L186.992,325"/>
            </g>

            <!-- Edge labels -->
            <g class="edgeLabels">
              <g transform="translate(165.98828125, 149)" class="edgeLabel">
                <g transform="translate(-16.8984375, -12)" class="label">
                  <foreignObject height="24" width="33.796875">
                    <div style="display: table-cell; white-space: nowrap; line-height: 1.5; max-width: 200px; text-align: center;" class="labelBkg" xmlns="http://www.w3.org/1999/xhtml">
                      <span class="edgeLabel">
                        <p>start</p>
                      </span>
                    </div>
                  </foreignObject>
                </g>
              </g>
              <g transform="translate(81.6328125, 263)" class="edgeLabel">
                <g transform="translate(-19.234375, -12)" class="label">
                  <foreignObject height="24" width="38.46875">
                    <div style="display: table-cell; white-space: nowrap; line-height: 1.5; max-width: 200px; text-align: center;" class="labelBkg" xmlns="http://www.w3.org/1999/xhtml">
                      <span class="edgeLabel">
                        <p>abort</p>
                      </span>
                    </div>
                  </foreignObject>
                </g>
              </g>
            </g>
          </g>
        </g>
      </svg>
    </div>
    """
  end
end
