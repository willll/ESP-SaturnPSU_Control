*** Settings ***
Library           SeleniumLibrary
Library           RequestsLibrary
Suite Setup       Open Browser To D1 UI
Suite Teardown    Close Browser

*** Variables ***
${URL}            http://192.168.1.107/   # ESP8266 device address
${SELENIUM_REMOTE_URL}    %{SELENIUM_REMOTE_URL}
${CHROME OPTIONS}    {"args": ["--no-sandbox", "--disable-dev-shm-usage"]}
${CHROME CAPABILITIES}    {"browserName": "chrome", "goog:chromeOptions": {"args": ["--no-sandbox", "--disable-dev-shm-usage"]}}

*** Test Cases ***
ON Button Green When D1 Is 1
    [Tags]    color    status
    Set D1 State    1
    Reload Page
    Element Attribute Value Should Be    id=btnOn    class    btn-on green
    Element Attribute Value Should Be    id=btnOff   class    btn-off red
    Element Should Be Disabled    id=btnOn
    Element Should Be Enabled     id=btnOff

OFF Button Green When D1 Is 0
    [Tags]    color    status
    Set D1 State    0
    Reload Page
    Element Attribute Value Should Be    id=btnOn    class    btn-on red
    Element Attribute Value Should Be    id=btnOff   class    btn-off green
    Element Should Be Disabled    id=btnOff
    Element Should Be Enabled     id=btnOn

Latch Input Enforces Min/Max
    [Tags]    latch    input
    Input Text    id=latchSeconds    0
    Press Key    id=latchSeconds    RETURN
    Element Attribute Value Should Be    id=latchSeconds    value    1
    Input Text    id=latchSeconds    9999
    Press Key    id=latchSeconds    RETURN
    Element Attribute Value Should Be    id=latchSeconds    value    3600

Debug Log Visible
    [Tags]    debug
    Element Should Be Visible    id=debug

GitHub Link In Footer
    [Tags]    footer
    Element Attribute Value Should Be    xpath=//footer//a    href    https://github.com/willll/ESP-SaturnPSU_Control

Polls Status Every 2 Seconds
    [Tags]    polling    ui
    # Set D1 state to 1 (ON)
    Set D1 State    1
    Reload Page
    Sleep    2.5s
    # Change D1 state to 0 (OFF) via API
    Set D1 State    0
    # Wait for polling interval
    Sleep    2.5s
    # Verify UI reflects new D1 state
    Element Attribute Value Should Be    id=btnOn    class    btn-on red
    Element Attribute Value Should Be    id=btnOff   class    btn-off green

API Error Handling And Feedback
    [Tags]    error    ui
    # Try to set D1 state during latch (should fail)
    Set D1 State    1
    Input Text    id=latchSeconds    2
    Press Key    id=latchSeconds    RETURN
    Sleep    0.5s
    # Attempt to set D1 OFF during latch
    ${resp}=    POST On Session    d1    api/v1/off
    Should Be Equal As Integers    ${resp.status_code}    423
    # UI should show error feedback (assume error log or popup)
    Element Should Be Visible    id=debug
    Page Should Contain    Latch active

Invalid API Request Shows Error
    [Tags]    error    ui
    # Send invalid API request
    ${resp}=    POST On Session    d1    api/v1/latch    json={'latch': -5}
    Should Be Equal As Integers    ${resp.status_code}    200
    # UI should show error or warning for invalid value
    Element Should Be Visible    id=debug
    Page Should Contain    latch

UI Is Self-Contained
    [Tags]    selfcontained    ui
    ${chrome options}=    Evaluate    sys.modules['selenium.webdriver'].ChromeOptions()    sys, selenium.webdriver
    Call Method    ${chrome options}    add_argument    --no-sandbox
    Call Method    ${chrome options}    add_argument    --disable-dev-shm-usage
    Open Browser    ${URL}    browser=chrome    remote_url=${SELENIUM_REMOTE_URL}    options=${chrome options}
    Maximize Browser Window
    Create Session    d1    ${URL}
    ${resources}=    Get WebElements    //link | //script | //img
    : FOR    ${el}    IN    @{resources}
    \    ${src}=    Get Element Attribute    ${el}    src
    \    Run Keyword If    '${src}' != ''    Should Contain    ${src}    ${URL}
    Close Browser

Open Source And Documentation Present
    [Tags]    opensource    docs    ui
    # Verify UI footer contains GitHub link
    Element Attribute Value Should Be    xpath=//footer//a    href    https://github.com/willll/ESP-SaturnPSU_Control
    # Verify documentation files exist in project
    ${readme}=    Get File    ../README.md
    Should Contain    ${readme}    ESP-SaturnPSU_Control
    ${srs}=    Get File    ../docs/SRS.md
    Should Contain    ${srs}    Software Requirements Specification

*** Keywords ***
Open Browser To D1 UI
    ${chrome options}=    Evaluate    sys.modules['selenium.webdriver'].ChromeOptions()    sys, selenium.webdriver
    Call Method    ${chrome options}    add_argument    --no-sandbox
    Call Method    ${chrome options}    add_argument    --disable-dev-shm-usage
    Open Browser    ${URL}    browser=chrome    remote_url=${SELENIUM_REMOTE_URL}    options=${chrome options}
    Maximize Browser Window
    Create Session    d1    ${URL}

Set D1 State
    [Arguments]    ${state}
    # Use API to set D1 state directly
    ${resp}=    POST On Session    d1    api/v1/${state == '1' and 'on' or 'off'}
    Should Be Equal As Integers    ${resp.status_code}    200

Reload Page
    Reload Page
