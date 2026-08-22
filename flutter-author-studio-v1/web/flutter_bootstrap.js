// Boots AuthorOS in the browser and owns the loading screen in index.html from
// first paint until Flutter has drawn its first frame — or until it is clear
// that it never will.
//
// Flutter generates this file when a project does not supply one. AuthorOS
// supplies it because something has to notice when the app does not arrive.
// The loading screen alone cannot: it has no way to tell "still downloading"
// from "the bundle 404'd", so a failed load leaves an author watching a
// sweeping progress bar forever, with the real error visible only in a console
// they will never open.
//
// The double-brace placeholders below are substituted by `flutter build web`,
// which injects the loader, the build manifest, and the service worker
// version. They are substituted anywhere they appear in this file, comments
// included, so do not name them outside the lines that use them.

{{flutter_js}}
{{flutter_build_config}}

(function () {
  'use strict';

  var screenEl = document.getElementById('authoros-loading');
  var diagnostic = document.getElementById('authoros-loading-diagnostic');

  // Long enough that a first visit on a slow connection still gets through --
  // the engine and the app bundle are a few megabytes cold -- and short enough
  // that a genuinely stuck load does not leave an author watching an animation
  // forever.
  var STARTUP_TIMEOUT_MS = 45000;

  var settled = false;
  var timeoutHandle = window.setTimeout(function () {
    fail(new Error('AuthorOS did not finish loading within ' +
      (STARTUP_TIMEOUT_MS / 1000) + ' seconds.'));
  }, STARTUP_TIMEOUT_MS);

  function settle() {
    if (settled) {
      return true;
    }
    settled = true;
    window.clearTimeout(timeoutHandle);
    return false;
  }

  // Flutter fires this on the window once it has painted its first frame. Fade
  // the loading screen out, then take it out of the tree entirely so it can
  // never sit above the app or trap pointer events.
  function dismiss() {
    if (settle() || !screenEl) {
      return;
    }
    screenEl.classList.add('authoros-loading--done');
    window.setTimeout(function () {
      if (screenEl.parentNode) {
        screenEl.parentNode.removeChild(screenEl);
      }
    }, 300);
  }

  function fail(error) {
    if (settle() || !screenEl) {
      return;
    }

    // The author gets a sentence they can act on. The developer keeps the real
    // error: it goes to the console, and into the collapsed "Technical
    // details" panel on the page itself.
    console.error('AuthorOS failed to start.', error);

    if (diagnostic) {
      diagnostic.textContent = String(
        (error && (error.stack || error.message)) || error
      );
    }
    screenEl.classList.add('authoros-loading--failed');
    screenEl.setAttribute('role', 'alert');

    // By far the most common cause is the obvious one, and saying so saves an
    // author from wondering whether their work is gone.
    if (navigator.onLine === false) {
      var message = screenEl.querySelector('.authoros-loading__message');
      if (message) {
        message.textContent =
          'AuthorOS couldn’t load because this device is offline. ' +
          'Reconnect and try again — your writing stays on this device.';
      }
    }

    var retry = document.getElementById('authoros-retry');
    if (retry) {
      retry.addEventListener('click', function () {
        window.location.reload();
      });
      retry.focus();
    }

    var returnToStart = document.getElementById('authoros-return');
    if (returnToStart) {
      returnToStart.addEventListener('click', function () {
        // Discard whatever section is in the address bar and reopen AuthorOS at
        // its entry point — the way out when one route is what is broken.
        var base = document.querySelector('base');
        window.location.href = (base && base.getAttribute('href')) || '/';
      });
    }
  }

  window.addEventListener('flutter-first-frame', dismiss);

  // The loader fetches the application bundle and the engine with script tags
  // and dynamic imports, and a failure there does not always reject the promise
  // chain below -- it surfaces as a resource error on the element. Without
  // this, a bundle that never arrives leaves an author watching the loading
  // animation until the backstop timeout, which is most of a minute of nothing
  // happening. Resource errors do not bubble, so this listens on the capture
  // phase.
  var ENTRY_POINTS = ['main.dart.js', 'flutter.js', 'canvaskit'];

  window.addEventListener('error', function (event) {
    var target = event.target;
    if (!target || target === window || !target.tagName) {
      return;
    }
    var source = target.src || target.href || '';
    var isEntryPoint = ENTRY_POINTS.some(function (name) {
      return source.indexOf(name) !== -1;
    });
    if (isEntryPoint) {
      fail(new Error('AuthorOS could not load ' + source));
    }
  }, true);

  try {
    _flutter.loader.load({
      serviceWorkerSettings: {
        serviceWorkerVersion: {{flutter_service_worker_version}},
      },
      onEntrypointLoaded: function (engineInitializer) {
        engineInitializer
          .initializeEngine()
          .then(function (appRunner) {
            return appRunner.runApp();
          })
          .catch(fail);
      },
    });
  } catch (error) {
    fail(error);
  }
})();
