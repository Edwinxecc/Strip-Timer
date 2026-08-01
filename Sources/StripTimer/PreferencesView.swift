import SwiftUI
import Observation

@Observable
class PreferencesModel {
    var curveType: String = PreferencesManager.shared.curveType {
        didSet { PreferencesManager.shared.curveType = curveType }
    }
    
    var stiffness: Double = PreferencesManager.shared.stiffness {
        didSet { PreferencesManager.shared.stiffness = stiffness }
    }
    
    var damping: Double = PreferencesManager.shared.damping {
        didSet { PreferencesManager.shared.damping = damping }
    }
    
    var sound: String = PreferencesManager.shared.sound {
        didSet {
            PreferencesManager.shared.sound = sound
            // Play a short preview when changed
            if let nssound = NSSound(named: sound) {
                nssound.play()
            }
        }
    }
}

struct PreferencesView: View {
    var model: PreferencesModel
    
    var body: some View {
        Form {
            Section(header: Text("Tensión de la Liga (Física)").font(.headline)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rigidez (Stiffness): \(Int(model.stiffness))")
                        .font(.body)
                    Slider(
                        value: Binding(
                            get: { model.stiffness },
                            set: { model.stiffness = $0 }
                        ),
                        in: 100.0...600.0,
                        step: 10.0
                    )
                }
                .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amortiguación (Damping): \(Int(model.damping))")
                        .font(.body)
                    Slider(
                        value: Binding(
                            get: { model.damping },
                            set: { model.damping = $0 }
                        ),
                        in: 5.0...50.0,
                        step: 1.0
                    )
                }
                .padding(.vertical, 4)
            }
            
            Divider()
            
            Section(header: Text("Conversión Distancia ➔ Tiempo").font(.headline)) {
                Picker(
                    "Curva de Conversión:",
                    selection: Binding(
                        get: { model.curveType },
                        set: { model.curveType = $0 }
                    )
                ) {
                    Text("Exponencial (Rampa rápida)").tag("exponential")
                    Text("Logarítmica (Progresión lenta)").tag("logarithmic")
                    Text("Lineal (Proporción constante)").tag("linear")
                }
                .pickerStyle(.radioGroup)
                .padding(.vertical, 4)
                
                Text("Controla cómo se relaciona la distancia de arrastre con la duración del temporizador.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            Section(header: Text("Alertas y Sonidos").font(.headline)) {
                Picker(
                    "Sonido al Finalizar:",
                    selection: Binding(
                        get: { model.sound },
                        set: { model.sound = $0 }
                    )
                ) {
                    Text("Glass (Cristal)").tag("Glass")
                    Text("Hero (Campana)").tag("Hero")
                    Text("Ping (Sonido corto)").tag("Ping")
                    Text("Morse (Código)").tag("Morse")
                }
                .pickerStyle(.menu)
                .padding(.vertical, 4)
            }
        }
        .padding(24)
        .frame(width: 420, height: 400)
    }
}
