// ── Loomy AST Playground — Frontend ──────────────────

let editor;
let currentData = null;
let currentView = 'pre'; // 'pre' | 'post' | 'diff'

// ── Init ────────────────────────────────────────────
document.addEventListener('DOMContentLoaded', () => {
  editor = CodeMirror.fromTextArea(document.getElementById('editor'), {
    mode: 'ruby',
    theme: 'dracula',
    lineNumbers: true,
    tabSize: 2,
    indentWithTabs: false,
    lineWrapping: true,
    autofocus: true,
  });

  // Keybinding: Ctrl+Enter to parse
  editor.setOption('extraKeys', {
    'Ctrl-Enter': () => parse(),
    'Cmd-Enter': () => parse(),
  });

  document.getElementById('btn-parse').addEventListener('click', parse);
  document.getElementById('btn-pre').addEventListener('click', () => switchView('pre'));
  document.getElementById('btn-post').addEventListener('click', () => switchView('post'));
  document.getElementById('btn-diff').addEventListener('click', () => switchView('diff'));
});

// ── Parse ───────────────────────────────────────────
async function parse() {
  const code = editor.getValue().trim();
  if (!code) return;

  const w = parseInt(document.getElementById('canvas-w').value) || 800;
  const h = parseInt(document.getElementById('canvas-h').value) || 600;

  const btn = document.getElementById('btn-parse');
  btn.textContent = 'Parsing...';
  btn.disabled = true;

  try {
    const res = await fetch('/api/parse', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ code, width: w, height: h }),
    });

    const data = await res.json();

    if (data.error) {
      showError(data.error);
      return;
    }

    currentData = data;
    renderTree();
    updateStats();
  } catch (err) {
    showError('Erro de conexão com o servidor');
  } finally {
    btn.textContent = 'Parse';
    btn.disabled = false;
  }
}

// ── View Toggle ─────────────────────────────────────
function switchView(view) {
  currentView = view;
  document.querySelectorAll('.btn-toggle').forEach(b => b.classList.remove('active'));
  document.getElementById(`btn-${view}`).classList.add('active');

  const titles = { pre: 'AST (Original)', post: 'AST (Otimizada)', diff: 'Diff (Antes vs Depois)' };
  document.getElementById('tree-title').textContent = titles[view];

  if (currentData) {
    renderTree();
    updateStats();
  }
}

// ── Render Tree ─────────────────────────────────────
function renderTree() {
  const container = document.getElementById('tree-container');
  if (!currentData) return;

  container.innerHTML = '';

  if (currentView === 'diff') {
    const tree = renderDiffTree(currentData.pre, currentData.post);
    container.appendChild(tree);
  } else {
    const data = currentView === 'pre' ? currentData.pre : currentData.post;
    const tree = renderNode(data);
    container.appendChild(tree);
  }
}

function renderNode(node, isRoot = true) {
  if (!node) return document.createTextNode('');

  const div = document.createElement('div');
  div.className = `tree-node node-${typeClass(node.type)} ${isRoot ? 'tree-root' : ''}`;

  const card = document.createElement('div');
  card.className = 'node-card';

  const icon = document.createElement('span');
  icon.className = 'node-icon';
  icon.textContent = nodeIcon(node.type);

  const type = document.createElement('span');
  type.className = 'node-type';
  type.textContent = node.type;

  const props = document.createElement('span');
  props.className = 'node-props';
  props.textContent = formatProps(node.properties);

  card.appendChild(icon);
  card.appendChild(type);
  card.appendChild(props);
  div.appendChild(card);

  // Effects
  if (node.effects) {
    node.effects.forEach(effect => {
      div.appendChild(renderNode(effect, false));
    });
  }

  // Children
  if (node.children) {
    node.children.forEach(child => {
      div.appendChild(renderNode(child, false));
    });
  }

  return div;
}

function renderDiffTree(pre, post) {
  return renderDiffNode(pre, post, true);
}

function renderDiffNode(preNode, postNode, isRoot = true) {
  if (!preNode) return document.createTextNode('');

  const removed = !postNode;

  const div = document.createElement('div');
  div.className = `tree-node node-${typeClass(preNode.type)} ${isRoot ? 'tree-root' : ''} ${removed ? 'node-removed' : ''}`;

  const card = document.createElement('div');
  card.className = 'node-card';

  const icon = document.createElement('span');
  icon.className = 'node-icon';
  icon.textContent = removed ? '✗' : nodeIcon(preNode.type);

  const type = document.createElement('span');
  type.className = 'node-type';
  type.textContent = preNode.type;

  const props = document.createElement('span');
  props.className = 'node-props';

  if (!removed && postNode) {
    const preProps = formatProps(preNode.properties);
    const postProps = formatProps(postNode.properties);
    if (preProps !== postProps) {
      props.innerHTML = `<span style="text-decoration:line-through;opacity:0.4">${escHtml(preProps)}</span> → <span style="color:#3fb950">${escHtml(postProps)}</span>`;
    } else {
      props.textContent = preProps;
    }
  } else {
    props.textContent = formatProps(preNode.properties);
  }

  if (removed) {
    const badge = document.createElement('span');
    badge.className = 'node-props';
    badge.style.color = '#f85149';
    badge.style.marginLeft = '6px';
    badge.textContent = '← REMOVIDO';
    card.appendChild(icon);
    card.appendChild(type);
    card.appendChild(props);
    card.appendChild(badge);
  } else {
    card.appendChild(icon);
    card.appendChild(type);
    card.appendChild(props);
  }

  div.appendChild(card);

  // Two-pointer matching for effects (optimizer preserves order, only removes)
  const preEffects = preNode.effects || [];
  const postEffects = (postNode && postNode.effects) || [];
  let ej = 0;
  for (let ei = 0; ei < preEffects.length; ei++) {
    if (ej < postEffects.length && postEffects[ej].type === preEffects[ei].type) {
      div.appendChild(renderDiffNode(preEffects[ei], postEffects[ej], false));
      ej++;
    } else {
      div.appendChild(renderDiffNode(preEffects[ei], null, false));
    }
  }

  // Two-pointer matching for children (optimizer preserves order, only removes)
  const preChildren = preNode.children || [];
  const postChildren = (postNode && postNode.children) || [];
  let cj = 0;
  for (let ci = 0; ci < preChildren.length; ci++) {
    if (cj < postChildren.length && nodesCorrespond(preChildren[ci], postChildren[cj])) {
      div.appendChild(renderDiffNode(preChildren[ci], postChildren[cj], false));
      cj++;
    } else {
      div.appendChild(renderDiffNode(preChildren[ci], null, false));
    }
  }

  return div;
}

// Check if a pre-optimization node corresponds to a post-optimization node.
// The optimizer never reorders children, so we only need to confirm identity.
function nodesCorrespond(preNode, postNode) {
  if (preNode.type !== postNode.type) return false;
  const prp = preNode.properties || {};
  const pop = postNode.properties || {};
  // Layers: match by stable content identifier (source, solid, text)
  if (preNode.type === 'Layer') {
    if (prp.source && pop.source) return prp.source === pop.source;
    if (prp.solid && pop.solid) return prp.solid === pop.solid;
    if (prp.text && pop.text) return prp.text === pop.text;
  }
  // Groups/Stacks/Canvas: same type in sequential context is sufficient
  return true;
}

// ── Helpers ─────────────────────────────────────────
function nodeIcon(type) {
  const icons = {
    Canvas: '▪', Layer: '▫', Group: '▸', Stack: '≡',
    Blur: '~', Grayscale: '◐', ColorAdjustment: '◆',
    Displacement: '≈', Lighting: '◉'
  };
  return icons[type] || '•';
}

function typeClass(type) {
  if (['Blur', 'Grayscale', 'ColorAdjustment', 'Displacement', 'Lighting'].includes(type)) return 'effect';
  return type.toLowerCase();
}

function formatProps(props) {
  if (!props || Object.keys(props).length === 0) return '';
  const parts = [];
  for (const [k, v] of Object.entries(props)) {
    if (v === null || v === undefined) continue;
    parts.push(`${k}: ${typeof v === 'string' ? `"${v}"` : v}`);
  }
  return parts.join(', ');
}

function escHtml(str) {
  return str.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

// ── Stats ───────────────────────────────────────────
function updateStats() {
  const bar = document.getElementById('stats-bar');
  const text = document.getElementById('stats-text');
  if (!currentData) { bar.classList.add('hidden'); return; }

  bar.classList.remove('hidden');

  const preCount = countNodes(currentData.pre);
  const postCount = countNodes(currentData.post);
  const removed = preCount - postCount;

  if (currentView === 'pre') {
    text.textContent = `${preCount} nós na árvore original`;
  } else if (currentView === 'post') {
    text.textContent = `${postCount} nós após otimização (${removed} removido${removed !== 1 ? 's' : ''})`;
  } else {
    text.textContent = `${preCount} nós originais → ${postCount} otimizados | ${removed} removido${removed !== 1 ? 's' : ''}`;
  }
}

function countNodes(node) {
  if (!node) return 0;
  let count = 1;
  (node.children || []).forEach(c => { count += countNodes(c); });
  (node.effects || []).forEach(e => { count += countNodes(e); });
  return count;
}

// ── Error Toast ─────────────────────────────────────
function showError(msg) {
  const toast = document.getElementById('error-toast');
  toast.textContent = `[!] ${msg}`;
  toast.classList.remove('hidden');
  setTimeout(() => toast.classList.add('hidden'), 4000);
}
