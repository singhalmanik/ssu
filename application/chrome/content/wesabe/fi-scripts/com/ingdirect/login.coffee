wesabe.provide 'fi-scripts.com.ingdirect.login',
  dispatch: ->
    tmp.authenticated = page.visible(e.signOffLink)
    return if tmp.authenticated

    url = browser.url
    if url and url.indexOf('pin_change_newpin') isnt -1
      # user is being asked to change their PIN
      job.fail 403, 'auth.pass.expired'
      return

    pinIsPresent = page.present bind(e.pinNumericButton, n: 1)

    if page.present e.login.errors.badCreds
      job.fail 401, 'auth.creds.invalid'
    else if page.present e.login.errors.lockedOut
      job.fail 403, 'auth.noaccess'
    else if pinIsPresent and page.visible(e.errors.general)
      job.fail 401, 'auth.creds.invalid'
    else if pinIsPresent
      action.pin()
    else if page.present e.security.answers
      action.answerSecurityQuestions()
    else if page.present e.login.user.input
      action.customerNumber()

  actions:
    main: ->
      browser.go 'https://secure.ingdirect.com/myaccount/'

    customerNumber: ->
      job.update 'auth.user'
      page.fill e.login.user.input, answers.customerNumber or answers.username
      page.click e.login.user.continueButton

    pin: ->
      # prevent filling in the PIN more than once per job, since that is almost
      # always an error and could result in the user getting locked out
      if tmp.haveGivenPinBefore
        return job.fail 401, 'auth.pass.invalid'
      else
        tmp.haveGivenPinBefore = true

      job.update 'auth.pass'

      pin = answers.pin or answers.password
      page.click e.pinKeyboardEntryLink

      pinmap =
        a: 2, b: 2, c: 2
        d: 3, e: 3, f: 3
        g: 4, h: 4, i: 4
        j: 5, k: 5, l: 5
        m: 6, n: 6, o: 6
        p: 7, q: 7, r: 7, s: 7
        t: 8, u: 8, v: 8
        w: 9, x: 9, y: 9, z: 9

      pinAsLetters = ''

      for i in [0...pin.length]
        # map letters to numbers using the above (telephone) mapping
        n = pinmap[pin[i].toLowerCase()] or pin[i]
        numericButton = page.findStrict(bind(e.pinNumericButton, {n}))
        charButton = page.next(numericButton, numericButton.nodeName)
        pinAsLetters += wesabe.untaint(charButton.getAttribute('alt'))

      pinAsLetters = wesabe.taint(pinAsLetters)

      page.fill e.pinPasswordField, pinAsLetters
      page.click e.pinSubmitButton

    logoff: ->
      job.succeed()
      page.click e.signOffLink

  elements:
    #############################################################################
    ## Step 1: Customer Number
    #############################################################################

    login:
      user:
        # the text field for the user to type in their Customer Number
        input: [
          '//input[@name="ACN"]'
          '//form[@name="Signin"]//input[@type="text"]'
        ]

        # a dropdown field containing the Customer Number the site remembers -- we shouldn't hit this
        select: [
          '//select[@name="ACN"]'
          '//form[@name="Signin"]//select'
        ]

        # the image button that says "Next" and advances to the next page
        continueButton: [
          '//a[@id="btn_continue"]'
          '//form[@name="Signin"]//a[@href="#" or @title="Continue"]'
          '//a[@title="Continue"]'
        ]

      errors:
        lockedOut: '//text()[contains(., "you have reached the maximum number of login failures")]'

        badCreds: '//*[has-class("errormsg")][contains(string(.), "check") or contains(string(.), "verify") or contains(string(.), "don\'t recognize")][contains(string(.), "Customer Number")]'

    #############################################################################
    ## Step 2: Security Questions
    #############################################################################

    security:
      questions: [
        '//label[has-class("question")]//text()'
      ]

      answers: [
        '//input[contains(@name, "AnswerQ")]'
        '//input[contains(@name, "customerAuthenticationResponse.questionAnswer")]'
      ]

      setCookieCheckbox: [
        '//form[@name="CustomerAuthenticate"]//input[@type="checkbox" and @name="RegisterDevice"]'
        '//input[@type="checkbox" and @name="RegisterDevice"]'
        '//input[@name="RegisterDevice"]'
        # ING Direct appears to be testing something where the input names have changed,
        # so these may be the only ones that work in the future.
        '//form[@name="CustomerAuthenticate"]//input[@type="checkbox" and contains(@name, "customerAuthenticationResponse.device")]'
        '//input[@type="checkbox" and contains(@name, "customerAuthenticationResponse.device")]'
        '//input[contains(@name, "customerAuthenticationResponse.device")]'
      ]

      continueButton: [
        '//a[@id="btn_continue"]'
        '//form[@name="CustomerAuthenticate"]//a[@href="#" or @title="Continue"]'
        '//a[@title="Continue"]'
      ]

    #############################################################################
    ## Step 3: Confirm Your Image and Phrase
    #############################################################################

    # nothing yet

    #############################################################################
    ## Step 4: PIN
    #############################################################################

    # the link to toggle to keyboard entry
    pinKeyboardEntryLink: [
      '//a[contains(string(.), "keyboard")][contains(@onclick, "togglePinPads")]'
    ]

    # the PIN field
    pinPasswordField: [
      '//input[@id="customerAuthenticationResponse.PIN"][@type="password"]'
      '//input[@type="password"]'
    ]

    # a pattern to match the numeric buttons on the pin pad
    pinNumericButton: [
      '//div[@id="keyOnly"]//img[contains(@src, "pinpad/:n.gif")]'
    ]

    # the GO button on the pin pad
    pinSubmitButton: [
      '//a[@id="btn_continue"]'
      '//form[@name="CustomerAuthenticate"]//a[@href="#" or @title="Continue"]'
      '//a[@title="Continue"]'
    ]

    # sign off link
    signOffLink: [
      '//a[contains(@href, "logout")]'
    ]

privacy = require 'util/privacy'
privacy.registerSanitizer 'ING PIN Digit', /pinpad\/\d\.gif|[A-Z]\.gif/g
privacy.registerSanitizer 'ING Security Question', /AnswerQ[\d\.]+/g
privacy.registerSanitizer 'ING PIN Alt Text', /\b(one|two|three|four|five|six|seven|eight|nine|zero)\b/g