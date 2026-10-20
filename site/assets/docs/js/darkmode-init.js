if (localStorage.getItem('theme') === null) {
  localStorage.setItem('theme', 'dark');
}

if (localStorage.getItem('theme') === 'dark') {
  document.documentElement.setAttribute('data-dark-mode', '');
}
