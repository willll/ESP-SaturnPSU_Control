*** Settings ***
Library           RequestsLibrary
Library           OperatingSystem
Library           Collections
Suite Setup       Setup Suite
Suite Teardown    Teardown Suite

*** Variables ***
${DEVICE_IP}      ${ENV:DEVICE_IP}
${BASE_URL}       http://${DEVICE_IP}
${SESSION}        d1session

*** Test Cases ***
Power On And WiFi
    [Tags]    firmware
    ${resp}=  GET On Session    ${SESSION}    /api/status
    Should Be Equal As Integers    ${resp.status_code}    200
    Dictionary Should Contain Key    ${resp.json()}    d1

POST On Sets D1 High
    [Tags]    api
    POST On Session    ${SESSION}    /api/on
    Sleep    0.5s
    ${resp}=  GET On Session    ${SESSION}    /api/status
    Should Be Equal As Integers    ${resp.json()['d1']}    1

POST Off Sets D1 Low
    [Tags]    api
    POST On Session    ${SESSION}    /api/off
    Sleep    0.5s
    ${resp}=  GET On Session    ${SESSION}    /api/status
    Should Be Equal As Integers    ${resp.json()['d1']}    0

POST Toggle Flips D1
    [Tags]    api
    ${before}=  GET On Session    ${SESSION}    /api/status
    ${prev}=    Set Variable    ${before.json()['d1']}
    POST On Session    ${SESSION}    /api/toggle
    Sleep    0.5s
    ${after}=  GET On Session    ${SESSION}    /api/status
    Should Not Be Equal    ${after.json()['d1']}    ${prev}

Menu Endpoint Returns Status
    [Tags]    api
    ${resp}=  GET On Session    ${SESSION}    /menu
    Should Contain    ${resp.text}    ESP8266 Status


Latch ON Reverts After Period
    [Tags]    latch
    # Set latch period to 2 seconds
    ${body}=    Create Dictionary    latch=2
    POST On Session    ${SESSION}    /api/latch    json=${body}
    Sleep    0.2s
    # Set D1 OFF to start
    POST On Session    ${SESSION}    /api/off
    Sleep    0.5s
    ${resp}=  GET On Session    ${SESSION}    /api/status
    Should Be Equal As Integers    ${resp.json()['d1']}    0
    # Toggle ON and verify auto-revert
    POST On Session    ${SESSION}    /api/on
    Sleep    0.5s
    ${resp}=  GET On Session    ${SESSION}    /api/status
    Should Be Equal As Integers    ${resp.json()['d1']}    1
    Sleep    2.5s
    ${resp}=  GET On Session    ${SESSION}    /api/status
    Should Be Equal As Integers    ${resp.json()['d1']}    0

Latch Disabled (0) Does Not Revert
    [Tags]    latch
    # Set latch period to 0 (disable)
    ${body}=    Create Dictionary    latch=0
    POST On Session    ${SESSION}    /api/latch    json=${body}
    Sleep    0.2s
    # Set D1 OFF to start
    POST On Session    ${SESSION}    /api/off
    Sleep    0.5s
    ${resp}=  GET On Session    ${SESSION}    /api/status
    Should Be Equal As Integers    ${resp.json()['d1']}    0
    # Toggle ON and verify no auto-revert
    POST On Session    ${SESSION}    /api/on
    Sleep    0.5s
    ${resp}=  GET On Session    ${SESSION}    /api/status
    Should Be Equal As Integers    ${resp.json()['d1']}    1
    Sleep    3.0s
    ${resp}=  GET On Session    ${SESSION}    /api/status
    Should Be Equal As Integers    ${resp.json()['d1']}    1

*** Keywords ***
Setup Suite
    Log    Starting ESP8266 D1 Control API tests
    Create Session    ${SESSION}    ${BASE_URL}

Teardown Suite
    Log    Test suite finished
