*** Settings ***
Library           SeleniumLibrary
Suite Setup       Open Browser To D1 UI
Suite Teardown    Close Browser

*** Variables ***
${URL}            http://localhost/   # Change to your ESP8266 address

*** Test Cases ***
ON Button Green When D1 Is 1
    [Tags]    color    status
    Set D1 State    1
    Reload Page
    Element Attribute Value Should Be    id=btnOn    class    btn-on green
    Element Attribute Value Should Be    id=btnOff   class    btn-off red

OFF Button Green When D1 Is 0
    [Tags]    color    status
    Set D1 State    0
    Reload Page
    Element Attribute Value Should Be    id=btnOn    class    btn-on red
    Element Attribute Value Should Be    id=btnOff   class    btn-off green

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

*** Keywords ***
Open Browser To D1 UI
    Open Browser    ${URL}    Chrome
    Maximize Browser Window

Set D1 State
    [Arguments]    ${state}
    # Use API to set D1 state directly
    ${resp}=    Post Request    d1    ${URL}api/${state == '1' and 'on' or 'off'}
    Should Be Equal As Integers    ${resp.status_code}    200

Reload Page
    Reload Page
