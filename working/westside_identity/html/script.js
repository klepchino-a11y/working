(() => {
  const resourceName =
    (typeof GetParentResourceName === 'function' && GetParentResourceName()) ||
    (function () {
      try {
        const url = new URL(window.location.href);
        const segments = url.pathname.split('/').filter(Boolean);
        return segments.length > 0 ? segments[0] : 'westside_identity';
      } catch (_) {
        return 'westside_identity';
      }
    })();

  const MIN_HEIGHT = 120;
  const MAX_HEIGHT = 220;
  const MIN_WEIGHT = 40;
  const MAX_WEIGHT = 200;
  const MIN_AGE = 18;
  const MAX_AGE = 100;

  const allowedArabicRegex = /^[ابتثجحخدذرزسشصضطظعغفقكلمنهوياةى\s]+$/;

  const app = document.getElementById('app');
  const form = document.getElementById('regForm');
  const submitBtn = document.getElementById('submitBtn');
  const formError = document.getElementById('formError');
  const fields = {
    firstName: document.getElementById('firstName'),
    lastName: document.getElementById('lastName'),
    dob: document.getElementById('dob'),
    height: document.getElementById('height'),
    gender: document.getElementById('gender'),
    weight: document.getElementById('weight'),
  };

  const helpers = {
    firstName: document.getElementById('firstNameError'),
    lastName: document.getElementById('lastNameError'),
    dob: document.getElementById('dobError'),
    height: document.getElementById('heightError'),
    weight: document.getElementById('weightError'),
  };

  const show = () => app.classList.remove('hidden');
  const hide = () => app.classList.add('hidden');

  const setFormError = (message) => {
    if (!message) {
      formError.classList.add('hidden');
      formError.textContent = '';
    } else {
      formError.classList.remove('hidden');
      formError.textContent = message;
    }
  };

  const setHelper = (key, message) => {
    const helper = helpers[key];
    if (!helper) return;

    if (!message) {
      helper.classList.add('hidden');
      helper.textContent = '';
    } else {
      helper.classList.remove('hidden');
      helper.textContent = message;
    }
  };

  const normalizeName = (value) => value.replace(/\s+/g, ' ').trim();

  const isValidArabicName = (value, allowEmpty = false) => {
    if (allowEmpty && !value) return true;
    if (!value) return false;
    return allowedArabicRegex.test(value);
  };

  const toDateSafe = (value) => (value ? new Date(value + 'T00:00:00') : null);

  const calculateAge = (date) => {
    if (!(date instanceof Date) || Number.isNaN(date.getTime())) return NaN;
    const today = new Date();
    let age = today.getFullYear() - date.getFullYear();
    const monthDiff = today.getMonth() - date.getMonth();
    if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < date.getDate())) {
      age--;
    }
    return age;
  };

  const formatDate = (value) => {
    const [year, month, day] = value.split('-');
    return `${day}/${month}/${year}`;
  };

  const post = (endpoint, payload = {}) =>
    fetch(`https://${resourceName}/${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(payload),
    }).catch(() => {});

  window.addEventListener('message', (event) => {
    if (!event?.data) return;
    if (event.data.action === 'openRegistration') {
      setFormError('');
      Object.values(helpers).forEach((helper) => helper && helper.classList.add('hidden'));
      show();
    } else if (event.data.action === 'closeRegistration') {
      hide();
    } else if (event.data.action === 'setError') {
      setFormError(event.data.message || 'حدث خطأ غير متوقع');
    }
  });

  form.addEventListener('submit', (event) => {
    event.preventDefault();
    setFormError('');

    const firstName = normalizeName(fields.firstName.value);
    const lastName = normalizeName(fields.lastName.value);
    const dobValue = fields.dob.value;
    const heightValue = Number.parseInt(fields.height.value, 10);
    const weightValue = Number.parseInt(fields.weight.value, 10);
    const genderValue = fields.gender.value === 'f' ? 'f' : 'm';

    let hasError = false;

    if (!isValidArabicName(firstName)) {
      setHelper('firstName', 'يجب كتابة الاسم الأول بالحروف العربية فقط');
      hasError = true;
    } else {
      setHelper('firstName');
    }

    if (!isValidArabicName(lastName)) {
      setHelper('lastName', 'يجب كتابة الاسم الأخير بالحروف العربية فقط');
      hasError = true;
    } else {
      setHelper('lastName');
    }

    const dobDate = toDateSafe(dobValue);
    const age = calculateAge(dobDate);
    if (!dobDate || Number.isNaN(age) || age < MIN_AGE || age > MAX_AGE) {
      setHelper(
        'dob',
        `تاريخ الميلاد غير صالح. العمر يجب أن يكون بين ${MIN_AGE} و ${MAX_AGE} سنة.`
      );
      hasError = true;
    } else {
      setHelper('dob');
    }

       if (!Number.isFinite(heightValue) || heightValue < MIN_HEIGHT || heightValue > MAX_HEIGHT) {
      setHelper('height', `الطول يجب أن يكون بين ${MIN_HEIGHT} و ${MAX_HEIGHT} سم.`);
      hasError = true;
    } else {
      setHelper('height');
    }

    if (!Number.isFinite(weightValue) || weightValue < MIN_WEIGHT || weightValue > MAX_WEIGHT) {
      setHelper('weight', `الوزن يجب أن يكون بين ${MIN_WEIGHT} و ${MAX_WEIGHT} كجم.`);
      hasError = true;
    } else {
      setHelper('weight');
    }

    if (hasError) return;

    submitBtn.disabled = true;
    submitBtn.textContent = 'جاري المعالجة...';

    const payload = {
      firstName,
      lastName,
      dateOfBirth: formatDate(dobValue),
      sex: genderValue,
      height: heightValue,
      weight: weightValue,
    };

    post('submitIdentity', payload).finally(() => {
      submitBtn.disabled = false;
      submitBtn.textContent = 'إنشاء الهوية';
    });
  });

  const backgroundVideo = document.getElementById('backgroundVideo');
  if (backgroundVideo) {
    backgroundVideo.addEventListener('ended', () => {
      backgroundVideo.currentTime = 0;
      backgroundVideo.play().catch(() => {});
    });
  }

  window.addEventListener('load', () => {
    post('ready');
  });
})();