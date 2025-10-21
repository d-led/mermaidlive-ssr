// State Machine Hook for minimal updates
// Only updates the specific elements that change, not the entire SVG

export const StateMachineUpdater = {
  mounted() {
    this.updateState(this.el.dataset.state, this.el.dataset.counter);
  },

  updated() {
    const newState = this.el.dataset.state;
    const newCounter = parseInt(this.el.dataset.counter);
    this.updateState(newState, newCounter);
  },

  updateState(state, counter) {
    // Remove inProgress class from all states
    document.querySelectorAll('.node.statediagram-state').forEach(node => {
      node.classList.remove('inProgress');
      const rect = node.querySelector('rect');
      const label = node.querySelector('.label');
      const nodeLabel = node.querySelector('.nodeLabel');
      
      if (rect) {
        rect.style.strokeDasharray = '';
        rect.style.strokeWidth = '';
      }
      if (label) {
        label.style.fontStyle = '';
      }
      if (nodeLabel) {
        nodeLabel.style.fontStyle = '';
      }
    });

    // Add inProgress class to current state
    const currentStateNode = document.querySelector(`#state-${state}-4, #state-${state}-5`);
    if (currentStateNode) {
      currentStateNode.classList.add('inProgress');
      const rect = currentStateNode.querySelector('rect');
      const label = currentStateNode.querySelector('.label');
      const nodeLabel = currentStateNode.querySelector('.nodeLabel');
      
      if (rect) {
        rect.style.strokeDasharray = '5 5';
        rect.style.strokeWidth = '3px';
      }
      if (label) {
        label.style.fontStyle = 'italic';
      }
      if (nodeLabel) {
        nodeLabel.style.fontStyle = 'italic';
      }
    }

    // Update note visibility and content
    const noteNode = document.querySelector('#state-working----note-5');
    if (noteNode) {
      if (state === 'working' && counter > 0) {
        noteNode.style.display = 'block';
        const noteText = noteNode.querySelector('.nodeLabel p');
        if (noteText) {
          noteText.textContent = counter.toString();
        }
      } else {
        noteNode.style.display = 'none';
      }
    }

    // Update note edge visibility
    const noteEdge = document.querySelector('#working-working----note-5');
    if (noteEdge) {
      noteEdge.style.display = state === 'working' && counter > 0 ? 'block' : 'none';
    }
  }
};
