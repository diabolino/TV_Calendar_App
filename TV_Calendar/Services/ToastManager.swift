//
//  ToastManager.swift
//  TV_Calendar
//
//  Created by Gouard matthieu on 06/12/2025.
//


import SwiftUI

enum ToastStyle {
    case success
    case error
    case info
    
    var color: Color {
        switch self {
        case .success: return Color.green
        case .error: return Color.red
        case .info: return Color.blue
        }
    }
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

struct Toast: Equatable {
    let message: String
    let style: ToastStyle
    let duration: TimeInterval = 3.0
}

@Observable
class ToastManager {
    static let shared = ToastManager()
    
    var currentToast: Toast? = nil
    
    // Pour éviter les conflits d'animation
    private var workItem: DispatchWorkItem?
    
    @MainActor
    func show(_ message: String, style: ToastStyle = .info) {
        // Annuler la fermeture précédente si on spamme
        workItem?.cancel()
        
        withAnimation(.snappy) {
            currentToast = Toast(message: message, style: style)
        }
        
        // Fermeture automatique après 3 secondes
        let task = DispatchWorkItem { [weak self] in
            withAnimation(.snappy) {
                self?.currentToast = nil
            }
        }
        workItem = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: task)
    }
}
