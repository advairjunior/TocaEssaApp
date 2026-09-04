import 'package:flutter/material.dart';

abstract final class CoresTocaEssa {
  static const fundo = Color(0xFF0B080F);
  static const superficie = Color(0xFF1A1820);
  static const superficieElevada = Color(0xFF211E2A);
  static const borda = Color(0xFF34303E);
  static const roxo = Color(0xFF784DFF);
  static const roxoClaro = Color(0xFFB781FF);
  static const rosa = Color(0xFFFF4D9D);
  static const texto = Color(0xFFFFFFFF);
  static const textoSecundario = Color(0xFFC8C2D0);
}

abstract final class TemaTocaEssa {
  static ThemeData get escuro {
    const esquema = ColorScheme.dark(
      primary: CoresTocaEssa.roxo,
      onPrimary: CoresTocaEssa.texto,
      primaryContainer: Color(0xFF2D175C),
      onPrimaryContainer: CoresTocaEssa.roxoClaro,
      secondary: CoresTocaEssa.roxoClaro,
      onSecondary: CoresTocaEssa.fundo,
      tertiary: CoresTocaEssa.rosa,
      onTertiary: CoresTocaEssa.texto,
      error: CoresTocaEssa.rosa,
      onError: CoresTocaEssa.texto,
      surface: CoresTocaEssa.superficie,
      onSurface: CoresTocaEssa.texto,
      outline: CoresTocaEssa.borda,
    );

    const textoBase = TextTheme(
      headlineMedium:
          TextStyle(fontSize: 30, fontWeight: FontWeight.w600, height: 1.2),
      headlineSmall:
          TextStyle(fontSize: 24, fontWeight: FontWeight.w600, height: 1.25),
      titleLarge:
          TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
      titleMedium:
          TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4),
      bodyLarge:
          TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
      bodyMedium:
          TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
      labelLarge:
          TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3),
      labelMedium:
          TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.3),
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: esquema,
      fontFamily: 'Poppins',
      textTheme: textoBase.apply(
        bodyColor: CoresTocaEssa.texto,
        displayColor: CoresTocaEssa.texto,
      ),
      scaffoldBackgroundColor: CoresTocaEssa.fundo,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: CoresTocaEssa.fundo,
        foregroundColor: CoresTocaEssa.texto,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: CoresTocaEssa.texto,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: CoresTocaEssa.superficie,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: CoresTocaEssa.borda),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CoresTocaEssa.superficie,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        labelStyle: const TextStyle(color: CoresTocaEssa.textoSecundario),
        hintStyle: const TextStyle(color: Color(0xFF827B8D)),
        border: _borda(CoresTocaEssa.borda),
        enabledBorder: _borda(CoresTocaEssa.borda),
        focusedBorder: _borda(CoresTocaEssa.roxoClaro, largura: 1.5),
        errorBorder: _borda(CoresTocaEssa.rosa),
        focusedErrorBorder: _borda(CoresTocaEssa.rosa, largura: 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          backgroundColor: CoresTocaEssa.roxo,
          foregroundColor: CoresTocaEssa.texto,
          disabledBackgroundColor: CoresTocaEssa.borda,
          disabledForegroundColor: const Color(0xFF8F8998),
          textStyle: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 56),
          foregroundColor: CoresTocaEssa.roxoClaro,
          side: const BorderSide(color: CoresTocaEssa.roxo),
          textStyle: const TextStyle(
              fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: CoresTocaEssa.roxoClaro),
      ),
      dividerTheme:
          const DividerThemeData(color: CoresTocaEssa.borda, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: CoresTocaEssa.superficieElevada,
        contentTextStyle:
            const TextStyle(fontFamily: 'Poppins', color: CoresTocaEssa.texto),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: CoresTocaEssa.roxoClaro),
      listTileTheme:
          const ListTileThemeData(iconColor: CoresTocaEssa.roxoClaro),
      dialogTheme: DialogThemeData(
        backgroundColor: CoresTocaEssa.superficie,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: CoresTocaEssa.superficie,
        surfaceTintColor: Colors.transparent,
        indicatorColor: CoresTocaEssa.roxoClaro,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((estados) => TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: estados.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w500,
              color: CoresTocaEssa.texto,
            )),
        iconTheme: WidgetStateProperty.resolveWith((estados) => IconThemeData(
              size: 22,
              color: estados.contains(WidgetState.selected)
                  ? CoresTocaEssa.fundo
                  : CoresTocaEssa.textoSecundario,
            )),
      ),
    );
  }

  static OutlineInputBorder _borda(Color cor, {double largura = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cor, width: largura),
      );
}
