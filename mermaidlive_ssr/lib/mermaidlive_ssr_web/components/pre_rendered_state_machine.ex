defmodule MermaidLiveSsrWeb.Components.PreRenderedStateMachine do
  @moduledoc """
  A LiveComponent that renders a state machine SVG based on pre-rendered templates.

  This component uses the pre-rendered SVG structure but dynamically applies:
  - The 'inProgress' class to the active state
  - Shows/hides the counter note when in 'working' state
  - Updates the counter value in the note

  This achieves minimal updates by only changing specific attributes rather than re-rendering the entire SVG.
  """
  use Phoenix.LiveComponent

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pre-rendered-state-machine">
      <svg aria-roledescription="stateDiagram" role="graphics-document document" viewBox="0 0 253.8984375 412" style="max-width: 253.898px; background-color: white;" class="statediagram" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns="http://www.w3.org/2000/svg" width="100%" id="my-svg">
        <style>
          #my-svg{font-family:"trebuchet ms",verdana,arial,sans-serif;font-size:16px;fill:#333;}
          @keyframes edge-animation-frame{from{stroke-dashoffset:0;}}
          @keyframes dash{to{stroke-dashoffset:0;}}
          #my-svg .edge-animation-slow{stroke-dasharray:9,5!important;stroke-dashoffset:900;animation:dash 50s linear infinite;stroke-linecap:round;}
          #my-svg .edge-animation-fast{stroke-dasharray:9,5!important;stroke-dashoffset:900;animation:dash 20s linear infinite;stroke-linecap:round;}
          #my-svg .error-icon{fill:#552222;}
          #my-svg .error-text{fill:#552222;stroke:#552222;}
          #my-svg .edge-thickness-normal{stroke-width:1px;}
          #my-svg .edge-thickness-thick{stroke-width:3.5px;}
          #my-svg .edge-pattern-solid{stroke-dasharray:0;}
          #my-svg .edge-thickness-invisible{stroke-width:0;fill:none;}
          #my-svg .edge-pattern-dashed{stroke-dasharray:3;}
          #my-svg .edge-pattern-dotted{stroke-dasharray:2;}
          #my-svg .marker{fill:#333333;stroke:#333333;}
          #my-svg .marker.cross{stroke:#333333;}
          #my-svg svg{font-family:"trebuchet ms",verdana,arial,sans-serif;font-size:16px;}
          #my-svg p{margin:0;}
          #my-svg defs #statediagram-barbEnd{fill:#333333;stroke:#333333;}
          #my-svg g.stateGroup text{fill:#9370DB;stroke:none;font-size:10px;}
          #my-svg g.stateGroup text{fill:#333;stroke:none;font-size:10px;}
          #my-svg g.stateGroup .state-title{font-weight:bolder;fill:#131300;}
          #my-svg g.stateGroup rect{fill:#ECECFF;stroke:#9370DB;}
          #my-svg g.stateGroup line{stroke:#333333;stroke-width:1;}
          #my-svg .transition{stroke:#333333;stroke-width:1;fill:none;}
          #my-svg .stateGroup .composit{fill:white;border-bottom:1px;}
          #my-svg .stateGroup .alt-composit{fill:#e0e0e0;border-bottom:1px;}
          #my-svg .state-note{stroke:#aaaa33;fill:#fff5ad;}
          #my-svg .state-note text{fill:black;stroke:none;font-size:10px;}
          #my-svg .stateLabel .box{stroke:none;stroke-width:0;fill:#ECECFF;opacity:0.5;}
          #my-svg .edgeLabel .label rect{fill:#ECECFF;opacity:0.5;}
          #my-svg .edgeLabel{background-color:rgba(232,232,232, 0.8);text-align:center;}
          #my-svg .edgeLabel p{background-color:rgba(232,232,232, 0.8);}
          #my-svg .edgeLabel rect{opacity:0.5;background-color:rgba(232,232,232, 0.8);fill:rgba(232,232,232, 0.8);}
          #my-svg .edgeLabel .label text{fill:#333;}
          #my-svg .label div .edgeLabel{color:#333;}
          #my-svg .stateLabel text{fill:#131300;font-size:10px;font-weight:bold;}
          #my-svg .node circle.state-start{fill:#333333;stroke:#333333;}
          #my-svg .node .fork-join{fill:#333333;stroke:#333333;}
          #my-svg .node circle.state-end{fill:#9370DB;stroke:white;stroke-width:1.5;}
          #my-svg .end-state-inner{fill:white;stroke-width:1.5;}
          #my-svg .node rect{fill:#ECECFF;stroke:#9370DB;stroke-width:1px;}
          #my-svg .node polygon{fill:#ECECFF;stroke:#9370DB;stroke-width:1px;}
          #my-svg #statediagram-barbEnd{fill:#333333;}
          #my-svg .statediagram-cluster rect{fill:#ECECFF;stroke:#9370DB;stroke-width:1px;}
          #my-svg .cluster-label,#my-svg .nodeLabel{color:#131300;}
          #my-svg .statediagram-cluster rect.outer{rx:5px;ry:5px;}
          #my-svg .statediagram-state .divider{stroke:#9370DB;}
          #my-svg .statediagram-state .title-state{rx:5px;ry:5px;}
          #my-svg .statediagram-cluster.statediagram-cluster .inner{fill:white;}
          #my-svg .statediagram-cluster.statediagram-cluster-alt .inner{fill:#f0f0f0;}
          #my-svg .statediagram-cluster .inner{rx:0;ry:0;}
          #my-svg .statediagram-state rect.basic{rx:5px;ry:5px;}
          #my-svg .statediagram-state rect.divider{stroke-dasharray:10,10;fill:#f0f0f0;}
          #my-svg .note-edge{stroke-dasharray:5;}
          #my-svg .statediagram-note rect{fill:#fff5ad;stroke:#aaaa33;stroke-width:1px;rx:0;ry:0;}
          #my-svg .statediagram-note rect{fill:#fff5ad;stroke:#aaaa33;stroke-width:1px;rx:0;ry:0;}
          #my-svg .statediagram-note text{fill:black;}
          #my-svg .statediagram-note .nodeLabel{color:black;}
          #my-svg .statediagram .edgeLabel{color:red;}
          #my-svg #dependencyStart,#my-svg #dependencyEnd{fill:#333333;stroke:#333333;stroke-width:1;}
          #my-svg .statediagramTitleText{text-anchor:middle;font-size:18px;fill:#333;}
          #my-svg :root{--mermaid-font-family:"trebuchet ms",verdana,arial,sans-serif;}
          #my-svg .inProgress>*{font-style:italic!important;stroke-dasharray:5 5!important;stroke-width:3px!important;}
          #my-svg .inProgress span{font-style:italic!important;stroke-dasharray:5 5!important;stroke-width:3px!important;}
        </style>
        <g>
          <defs>
            <marker orient="auto" markerUnits="userSpaceOnUse" markerHeight="14" markerWidth="20" refY="7" refX="19" id="my-svg_stateDiagram-barbEnd">
              <path d="M 19,7 L9,13 L14,7 L9,1 Z"/>
            </marker>
          </defs>
          <g class="root">
            <g class="clusters">
              <g id="working----parent" class="note-cluster">
                <rect fill="none" height="104" width="108.390625" y="300" x="128.0859375"/>
              </g>
            </g>
            <g class="edgePaths">
              <path marker-end="url(#my-svg_stateDiagram-barbEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid transition" id="edge0" d="M72.016,22L72.016,26.167C72.016,30.333,72.016,38.667,72.016,47C72.016,55.333,72.016,63.667,72.016,67.833L72.016,72"/>
              <path marker-end="url(#my-svg_stateDiagram-barbEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid transition" id="edge1" d="M104.162,112L114.074,118.167C123.986,124.333,143.809,136.667,151.725,149C159.641,161.333,155.649,173.667,153.653,179.833L151.657,186"/>
              <path marker-end="url(#my-svg_stateDiagram-barbEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid transition" id="edge2" d="M122.885,226L116.01,232.167C109.134,238.333,95.384,250.667,88.508,263C81.633,275.333,81.633,287.667,77.969,299.167C74.304,310.667,66.976,321.333,63.311,326.667L59.647,332"/>
              <path marker-end="url(#my-svg_stateDiagram-barbEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid transition" id="edge3" d="M119.511,186L111.595,179.833C103.679,173.667,87.847,161.333,79.931,149C72.016,136.667,72.016,124.333,72.016,118.167L72.016,112"/>
              <path marker-end="url(#my-svg_stateDiagram-barbEnd)" style="fill:none;" class="edge-thickness-normal edge-pattern-solid transition" id="edge4" d="M38.361,332L36.349,326.667C34.337,321.333,30.313,310.667,28.301,299.167C26.289,287.667,26.289,275.333,26.289,259.667C26.289,244,26.289,225,26.289,206C26.289,187,26.289,168,31.236,152.333C36.183,136.667,46.077,124.333,51.024,118.167L55.971,112"/>
              <path style={if @state == "working" and @counter > 0, do: "fill:none;", else: "fill:none;display:none;"} class="edge-thickness-normal edge-pattern-solid transition note-edge" id="working-working----note-5" d="M158.2,226L162.214,232.167C166.227,238.333,174.254,250.667,178.268,263C182.281,275.333,182.281,287.667,182.281,298C182.281,308.333,182.281,316.667,182.281,320.833L182.281,325"/>
            </g>
            <g class="edgeLabels">
              <g class="edgeLabel">
                <g transform="translate(0, 0)" class="label">
                  <foreignObject height="0" width="0">
                    <div style="display: table-cell; white-space: nowrap; line-height: 1.5; max-width: 200px; text-align: center;" class="labelBkg" xmlns="http://www.w3.org/1999/xhtml">
                      <span class="edgeLabel"></span>
                    </div>
                  </foreignObject>
                </g>
              </g>
              <g transform="translate(163.6328125, 149)" class="edgeLabel" phx-click="start" style={if @state == "waiting", do: "cursor: pointer;", else: "cursor: default; opacity: 0.5;"} role="button" tabindex={if @state == "waiting", do: "0", else: "-1"} aria-label="Start countdown">
                <g transform="translate(-16.8984375, -12)" class="label">
                  <foreignObject height="24" width="33.796875">
                    <div style="display: table-cell; white-space: nowrap; line-height: 1.5; max-width: 200px; text-align: center;" class="labelBkg" xmlns="http://www.w3.org/1999/xhtml">
                      <span class="edgeLabel" style="text-decoration: underline;"><p>start</p></span>
                    </div>
                  </foreignObject>
                </g>
              </g>
              <g transform="translate(81.6328125, 263)" class="edgeLabel" phx-click="abort" style={if @state == "working", do: "cursor: pointer;", else: "cursor: default; opacity: 0.5;"} role="button" tabindex={if @state == "working", do: "0", else: "-1"} aria-label="Abort countdown">
                <g transform="translate(-19.234375, -12)" class="label">
                  <foreignObject height="24" width="38.46875">
                    <div style="display: table-cell; white-space: nowrap; line-height: 1.5; max-width: 200px; text-align: center;" class="labelBkg" xmlns="http://www.w3.org/1999/xhtml">
                      <span class="edgeLabel" style="text-decoration: underline;"><p>abort</p></span>
                    </div>
                  </foreignObject>
                </g>
              </g>
              <g class="edgeLabel">
                <g transform="translate(0, 0)" class="label">
                  <foreignObject height="0" width="0">
                    <div style="display: table-cell; white-space: nowrap; line-height: 1.5; max-width: 200px; text-align: center;" class="labelBkg" xmlns="http://www.w3.org/1999/xhtml">
                      <span class="edgeLabel"></span>
                    </div>
                  </foreignObject>
                </g>
              </g>
              <g class="edgeLabel">
                <g transform="translate(0, 0)" class="label">
                  <foreignObject height="0" width="0">
                    <div style="display: table-cell; white-space: nowrap; line-height: 1.5; max-width: 200px; text-align: center;" class="labelBkg" xmlns="http://www.w3.org/1999/xhtml">
                      <span class="edgeLabel"></span>
                    </div>
                  </foreignObject>
                </g>
              </g>
              <g class="edgeLabel">
                <g transform="translate(0, 0)" class="label">
                  <foreignObject height="0" width="0">
                    <div style="display: table-cell; white-space: nowrap; line-height: 1.5; max-width: 200px; text-align: center;" class="labelBkg" xmlns="http://www.w3.org/1999/xhtml">
                      <span class="edgeLabel"></span>
                    </div>
                  </foreignObject>
                </g>
              </g>
            </g>
            <g class="nodes">
              <g transform="translate(72.015625, 15)" id="state-root_start-0" class="node default">
                <circle height="14" width="14" r="7" class="state-start"/>
              </g>
              <g transform="translate(72.015625, 92)" id="state-waiting-4" class={"node #{if @state == "waiting", do: "inProgress", else: ""} statediagram-state"}>
                <rect height="40" width="68.5625" y="-20" x="-34.28125" ry="5" rx="5" style="" class="basic label-container"/>
                <g transform="translate(-26.28125, -12)" style="" class="label">
                  <rect/><foreignObject height="24" width="52.5625"><div style="display: table-cell; white-space: nowrap; line-height: 1.5; max-width: 200px; text-align: center;" xmlns="http://www.w3.org/1999/xhtml"><span class="nodeLabel"><p>waiting</p></span></div></foreignObject></g>
              </g>
              <g transform="translate(145.18359375, 206)" id="state-working-5" class={"node #{if @state == "working", do: "inProgress", else: ""} statediagram-state"}>
                <rect height="40" width="72.90625" y="-20" x="-36.453125" ry="5" rx="5" style="" class="basic label-container"/>
                <g transform="translate(-28.453125, -12)" style="" class="label">
                  <rect/><foreignObject height="24" width="56.90625"><div style="display: table-cell; white-space: nowrap; line-height: 1.5; max-width: 200px; text-align: center;" xmlns="http://www.w3.org/1999/xhtml"><span class="nodeLabel"><p>working</p></span></div></foreignObject></g>
              </g>
              <g transform="translate(45.90625, 352)" id="state-aborting-4" class={"node #{if @state == "aborting", do: "inProgress", else: ""} statediagram-state"}>
                <rect height="40" width="75.8125" y="-20" x="-37.90625" ry="5" rx="5" style="" class="basic label-container"/>
                <g transform="translate(-29.90625, -12)" style="" class="label">
                  <rect/><foreignObject height="24" width="59.8125"><div style="display: table-cell; white-space: nowrap; line-height: 1.5; max-width: 200px; text-align: center;" xmlns="http://www.w3.org/1999/xhtml"><span class="nodeLabel"><p>aborting</p></span></div></foreignObject></g>
              </g>
              <g transform="translate(186.9921875, 352)" id="state-working----note-5" class="node statediagram-note" style={if @state == "working" and @counter > 0, do: "display: block", else: "display: none"}>
                <g class="basic label-container">
                  <path style="" fill="#fff5ad" stroke-width="0" stroke="none" d="M-23.90625 -27 L23.90625 -27 L23.90625 27 L-23.90625 27"/>
                  <path style="" fill="none" stroke-width="1.3" stroke="#aaaa33" d="M-23.90625 -27 C-9.358431101611824 -27, 5.1893877967763515 -27, 23.90625 -27 M-23.90625 -27 C-12.603517640762043 -27, -1.3007852815240852 -27, 23.90625 -27 M23.90625 -27 C23.90625 -13.408453109653717, 23.90625 0.1830937806925661, 23.90625 27 M23.90625 -27 C23.90625 -12.303017171874208, 23.90625 2.3939656562515843, 23.90625 27 M23.90625 27 C11.95612653861596 27, 0.006003077231920173 27, -23.90625 27 M23.90625 27 C13.569344700757874 27, 3.232439401515748 27, -23.90625 27 M-23.90625 27 C-23.90625 15.781228902791947, -23.90625 4.562457805583893, -23.90625 -27 M-23.90625 27 C-23.90625 5.929264102285963, -23.90625 -15.141471795428075, -23.90625 -27"/>
                </g>
                <g transform="translate(-8.90625, -12)" style="" class="label">
                  <rect/><foreignObject height="24" width="17.8125"><div style="display: flex; align-items: center; justify-content: center; height: 100%; width: 100%; text-align: center;" xmlns="http://www.w3.org/1999/xhtml"><span class="nodeLabel"><p style="margin: 0; padding: 0;"><%= @counter %></p></span></div></foreignObject></g>
              </g>
            </g>
          </g>
        </g>
      </svg>
    </div>
    """
  end
end
