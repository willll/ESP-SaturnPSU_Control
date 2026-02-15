# ESP8266 Relay Control - KiCAD Project

## What's in this project?

This is a starter KiCAD project for controlling an Omron G6B-1114P-US 12VDC relay
from an ESP8266 NodeMCU using a 2N2222 NPN transistor.

## Files included:

- `ESP8266_Relay_Control.kicad_pro` - Project file
- `ESP8266_Relay_Control.kicad_sch` - Schematic (stub, needs components added)
- `ESP8266_Relay_Control.kicad_pcb` - PCB layout (empty, update from schematic)
- `README.md` - This file
- `KiCAD_Import_Guide.txt` - Detailed step-by-step instructions

## Quick Start:

1. **Open the project in KiCAD 7.0 or later**
   - Double-click `ESP8266_Relay_Control.kicad_pro`
   
2. **Open the schematic editor**
   - Double-click the `.kicad_sch` file in the project window
   
3. **Follow the instructions in `KiCAD_Import_Guide.txt`**
   - This guide walks you through adding each component
   - Shows you how to wire them together
   - Explains how to create the PCB layout
   
4. **Add components** (Press 'A' in schematic editor):
   - J1: Conn_01x03 (ESP8266 connector) - Reference: J1, Value: ESP8266_NodeMCU
   - R1: R (Resistor) - Reference: R1, Value: 1k
   - Q1: Q_NPN_BCE (Transistor) - Reference: Q1, Value: 2N2222
   - D1: D (Diode) - Reference: D1, Value: 1N4007
   - K1: Relay_SPST - Reference: K1, Value: G6B-1114P-US
   - J2: Conn_01x02 (12V connector) - Reference: J2, Value: 12V_Supply
   - Power symbols: +12V and GND (Press 'P')

5. **Wire the components** (Press 'W'):
   - Follow the wiring diagram in the documentation
   - See `Circuit_Schematic_ASCII.txt` for reference

6. **Assign footprints**:
   - Tools → Assign Footprints
   - R1 → Resistor_THT:R_Axial_DIN0207_L6.3mm_D2.5mm_P10.16mm_Horizontal
   - Q1 → Package_TO_SOT_THT:TO-92_Inline
   - D1 → Diode_THT:D_DO-41_SOD81_P10.16mm_Horizontal
   - K1 → Relay_THT:Relay_SPST_Omron_G6B (or custom)
   - J1, J2 → Connector_PinHeader_2.54mm

7. **Update PCB from schematic**:
   - Tools → Update PCB from Schematic (F8)
   - Click "Update PCB"

8. **Design the PCB**:
   - Draw board outline on Edge.Cuts layer
   - Place components
   - Route traces
   - Add ground plane
   - Run DRC

9. **Generate Gerbers for manufacturing**:
   - File → Fabrication Outputs → Gerbers
   - Upload to JLCPCB, PCBWay, or other manufacturer

## Component List (BOM):

| Ref | Value | Part Number | Footprint |
|-----|-------|-------------|-----------|
| J1 | ESP8266_NodeMCU | NodeMCU ESP-12E | Connector 3-pin |
| R1 | 1k | 1kΩ 1/4W | R_Axial_DIN0207 |
| Q1 | 2N2222 | 2N2222 | TO-92 |
| D1 | 1N4007 | 1N4007 | DO-41 |
| K1 | G6B-1114P-US | Omron Relay 12VDC | Relay 4-pin |
| J2 | 12V_Supply | Terminal Block | Connector 2-pin |

## Key Connections:

- ESP8266 D1 (GPIO5) → R1 → Q1 Base
- ESP8266 GND → Common GND
- Q1 Emitter → GND
- Q1 Collector → Relay Pin 2 (Coil -)
- +12V → Relay Pin 1 (Coil +)
- +12V → D1 Cathode (stripe)
- D1 Anode → Q1 Collector / Relay Pin 2
- 12V Supply GND → Common GND

**CRITICAL: Common ground between ESP8266 and 12V supply is mandatory!**

## Documentation:

- `BOM_ESP8266_Relay_Control.txt` - Complete bill of materials
- `Circuit_Schematic_ASCII.txt` - ASCII art schematic with calculations
- `KiCAD_Import_Guide.txt` - Detailed KiCAD instructions
- `Quick_Reference_Guide.txt` - Quick reference for building

## Need Help?

1. Read `KiCAD_Import_Guide.txt` for step-by-step instructions
2. Check `Quick_Reference_Guide.txt` for pinouts and troubleshooting
3. See `Circuit_Schematic_ASCII.txt` for the complete circuit diagram
4. Visit KiCAD forums: https://forum.kicad.info/

## Version:

- Project: 1.0
- KiCAD: 7.0+
- Date: 2024-02-15

## License:

This project is provided as-is for educational purposes.
Use at your own risk. Always verify connections before applying power!
