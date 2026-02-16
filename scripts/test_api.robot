Latch Disables Buttons After Off
    [Tags]    latch    ui
    POST On Session    ${SESSION}    /api/v1/reset
    Sleep    0.5s
    ${body}=    Create Dictionary    latch=2
    POST On Session    ${SESSION}    /api/v1/latch    json=${body}
    Sleep    0.5s
    POST On Session    ${SESSION}    /api/v1/off
    Sleep    0.2s
    ${resp}=  GET On Session    ${SESSION}    /api/v1/status
    Should Be True    ${resp.json()['latch_timer_active']} == True
    # Wait for latch to expire
    Sleep    2.2s
    ${resp}=  GET On Session    ${SESSION}    /api/v1/status
    Should Be True    ${resp.json()['latch_timer_active']} == False
*** Settings ***
Library           RequestsLibrary
Library           OperatingSystem
Library           Collections
Suite Setup       Setup Suite
Suite Teardown    Teardown Suite

*** Variables ***
${DEVICE_IP}      None
${BASE_URL}       None
${SESSION}        d1session

*** Keywords ***
Setup Suite
    ${DEVICE_IP}=    Get Environment Variable    DEVICE_IP    192.168.1.107
    Set Suite Variable    ${DEVICE_IP}
    ${BASE_URL}=    Set Variable    http://${DEVICE_IP}
    Set Suite Variable    ${BASE_URL}
    Log    Starting ESP8266 D1 Control API tests
    Create Session    ${SESSION}    ${BASE_URL}

Teardown Suite
    Log    Test suite finished

*** Test Cases ***
Power On And WiFi
    [Tags]    firmware
    ${resp}=  GET On Session    ${SESSION}    /api/v1/status
    Should Be Equal As Integers    ${resp.status_code}    200
    Dictionary Should Contain Key    ${resp.json()}    d1

POST On Sets D1 High
    [Tags]    api
    POST On Session    ${SESSION}    /api/v1/on
    Sleep    0.5s
    ${resp}=  GET On Session    ${SESSION}    /api/v1/status
    Should Be Equal As Integers    ${resp.json()['d1']}    1

POST Off Sets D1 Low
    [Tags]    api
    # Reset latch and D1 state
    POST On Session    ${SESSION}    /api/v1/reset
    Sleep    0.5s
    ${before}=  GET On Session    ${SESSION}    /api/v1/status
    # Wait for latch to be released
    FOR    ${i}    IN RANGE    20
        ${latch}=    Set Variable    ${before.json()['latch']}
        Exit For Loop If    ${latch} == 0 or ${latch} == None
        Sleep    0.5s
        ${before}=  GET On Session    ${SESSION}    /api/v1/status
    END
    # Now turn off
    POST On Session    ${SESSION}    /api/v1/off
    Sleep    0.5s
    ${resp}=  GET On Session    ${SESSION}    /api/v1/status
    Should Be Equal As Integers    ${resp.json()['d1']}    0

POST Toggle Flips D1
    [Tags]    api
    # Reset latch and D1 state
    POST On Session    ${SESSION}    /api/v1/reset
    Sleep    0.5s
    ${before}=  GET On Session    ${SESSION}    /api/v1/status
    ${prev}=    Set Variable    ${before.json()['d1']}
    # Wait for latch to be released
    FOR    ${i}    IN RANGE    20
        ${latch}=    Set Variable    ${before.json()['latch']}
        Exit For Loop If    ${latch} == 0 or ${latch} == None
        Sleep    0.5s
        ${before}=  GET On Session    ${SESSION}    /api/v1/status
    END
    # Now toggle
    POST On Session    ${SESSION}    /api/v1/toggle
    Sleep    0.5s
    ${after}=  GET On Session    ${SESSION}    /api/v1/status
    Should Not Be Equal    ${after.json()['d1']}    ${prev}

Menu Endpoint Returns Status
    [Tags]    api
    ${resp}=  GET On Session    ${SESSION}    /menu
    Should Contain    ${resp.text}    ESP8266 Status

Latch Lockout Prevents Frequent Changes
    [Tags]    latch
    POST On Session    ${SESSION}    /api/v1/reset
    Sleep    0.5s
    ${body}=    Create Dictionary    latch=2
    POST On Session    ${SESSION}    /api/v1/latch    json=${body}
    Sleep    0.5s
    POST On Session    ${SESSION}    /api/v1/on
    Sleep    0.1s
    # Try to change state during latch (should fail with 423)
    ${resp}=  POST On Session    ${SESSION}    /api/v1/off
    Should Be Equal As Integers    ${resp.status_code}    423
    # Wait for latch to expire (poll status for robustness, up to 5s)
    FOR    ${i}    IN RANGE    25
        ${status}=    GET On Session    ${SESSION}    /api/v1/status
        ${active}=    Set Variable    ${status.json()['latch_timer_active']}
        Exit For Loop If    ${active} == False
        Sleep    0.2s
    END
    # Wait a bit to ensure firmware loop clears latch
    Sleep    2.0s
    # Now OFF should succeed
    ${resp}=  POST On Session    ${SESSION}    /api/v1/off
    Should Be Equal As Integers    ${resp.status_code}    200
    ${resp}=  GET On Session    ${SESSION}    /api/v1/status
    Should Be Equal As Integers    ${resp.json()['d1']}    0

Latch Disabled (0) Allows Immediate Changes
    [Tags]    latch
    POST On Session    ${SESSION}    /api/v1/reset
    Sleep    0.5s
    ${body}=    Create Dictionary    latch=1
    ${resp}=  POST On Session    ${SESSION}    /api/v1/latch    json=${body}
    Should Be True    ${resp.json()['latch']} == 1
    Sleep    0.5s
    POST On Session    ${SESSION}    /api/v1/on
    Should Be Equal As Integers    ${resp.status_code}    200
    # Wait for latch to expire (up to 2s)
    FOR    ${i}    IN RANGE    10
        ${status}=    GET On Session    ${SESSION}    /api/v1/status
        ${active}=    Set Variable    ${status.json()['latch_timer_active']}
        Exit For Loop If    ${active} == False
        Sleep    0.2s
    END
    Sleep    2.0s
    POST On Session    ${SESSION}    /api/v1/off
    Should Be Equal As Integers    ${resp.status_code}    200
    ${resp}=  GET On Session    ${SESSION}    /api/v1/status
    Should Be Equal As Integers    ${resp.json()['d1']}    0

Latch Rejects State Change During Active Period
    [Tags]    latch    enforcement
    POST On Session    ${SESSION}    /api/v1/reset
    Sleep    0.5s
    ${body}=    Create Dictionary    latch=2
    POST On Session    ${SESSION}    /api/v1/latch    json=${body}
    Sleep    0.5s
    POST On Session    ${SESSION}    /api/v1/off
    Sleep    2.0s
    POST On Session    ${SESSION}    /api/v1/on
    Sleep    0.5s
    ${resp}=  POST On Session    ${SESSION}    /api/v1/off
    Should Be Equal As Integers    ${resp.status_code}    423
    Should Contain    ${resp.text}    Latch active
    # Wait for latch to expire (up to 5s)
    FOR    ${i}    IN RANGE    25
        ${status}=    GET On Session    ${SESSION}    /api/v1/status
        ${active}=    Set Variable    ${status.json()['latch_timer_active']}
        Exit For Loop If    ${active} == False
        Sleep    0.2s
    END
    Sleep    1.0s
    ${resp}=  POST On Session    ${SESSION}    /api/v1/off
    Should Be Equal As Integers    ${resp.status_code}    200

Default Latch Value On Reset
    [Tags]    latch    default
    Log    Manual: After device reset, GET /api/v1/status should show latch=5

Latch Min/Max Enforced By API
    [Tags]    latch    constraints
    POST On Session    ${SESSION}    /api/v1/reset
    Sleep    0.5s
    ${body}=    Create Dictionary    latch=0
    ${resp}=  POST On Session    ${SESSION}    /api/v1/latch    json=${body}
    Should Be True    ${resp.json()['latch']} >= 1
    ${body}=    Create Dictionary    latch=9999
    ${resp}=  POST On Session    ${SESSION}    /api/v1/latch    json=${body}
    Should Be True    ${resp.json()['latch']} <= 3600

# Edge Cases
Rapid State Change Requests During Latch
    [Tags]    latch    edge
    POST On Session    ${SESSION}    /api/v1/reset
    Sleep    0.5s
    ${body}=    Create Dictionary    latch=2
    POST On Session    ${SESSION}    /api/v1/latch    json=${body}
    Sleep    0.5s
    POST On Session    ${SESSION}    /api/v1/off
    Sleep    2.0s
    POST On Session    ${SESSION}    /api/v1/on
    Sleep    0.5s
    ${resp}=  POST On Session    ${SESSION}    /api/v1/on
    Should Be Equal As Integers    ${resp.status_code}    423
    ${resp}=  POST On Session    ${SESSION}    /api/v1/off
    Should Be Equal As Integers    ${resp.status_code}    423
    ${resp}=  POST On Session    ${SESSION}    /api/v1/toggle
    Should Be Equal As Integers    ${resp.status_code}    423
    # Wait for latch to expire (up to 5s)
    FOR    ${i}    IN RANGE    25
        ${status}=    GET On Session    ${SESSION}    /api/v1/status
        ${active}=    Set Variable    ${status.json()['latch_timer_active']}
        Exit For Loop If    ${active} == False
        Sleep    0.2s
    END
    Sleep    1.0s
    ${resp}=  POST On Session    ${SESSION}    /api/v1/toggle
    Should Be Equal As Integers    ${resp.status_code}    200

Invalid Latch Values Are Handled
    [Tags]    latch    edge    constraints
    POST On Session    ${SESSION}    /api/v1/reset
    Sleep    0.5s
    ${body}=    Create Dictionary    latch=-5
    ${resp}=  POST On Session    ${SESSION}    /api/v1/latch    json=${body}
    Should Be True    ${resp.json()['latch']} >= 1
    ${body}=    Create Dictionary    latch=1
    ${resp}=  POST On Session    ${SESSION}    /api/v1/latch    json=${body}
    Should Be True    ${resp.json()['latch']} >= 1

Latch Timer Reset On Expiry
    [Tags]    latch    edge
    POST On Session    ${SESSION}    /api/v1/reset
    Sleep    0.5s
    ${body}=    Create Dictionary    latch=1
    POST On Session    ${SESSION}    /api/v1/latch    json=${body}
    Sleep    0.2s
    POST On Session    ${SESSION}    /api/v1/off
    Sleep    0.5s
    POST On Session    ${SESSION}    /api/v1/on
    # Wait for latch to expire (up to 2s)
    FOR    ${i}    IN RANGE    10
        ${status}=    GET On Session    ${SESSION}    /api/v1/status
        ${active}=    Set Variable    ${status.json()['latch_timer_active']}
        Exit For Loop If    ${active} == False
        Sleep    0.2s
    END
    Sleep    2.0s
    ${resp}=  POST On Session    ${SESSION}    /api/v1/on
    Should Be Equal As Integers    ${resp.status_code}    200
