// A kit that applies its focus state a frame after the event (as Vuetify does through Vue's render).
const late = document.getElementById('late');
late.addEventListener('focus', () => requestAnimationFrame(() => late.parentElement.classList.add('late-field--focused')));
late.addEventListener('blur', () => requestAnimationFrame(() => late.parentElement.classList.remove('late-field--focused')));
