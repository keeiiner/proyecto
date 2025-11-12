library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--------------------------------------------------------------------
-- Módulo: top_juego
-- Descripción: Sistema de juego "Adivina el Número"
-- - Genera número pseudoaleatorio de 4 bits (0-15)
-- - Usuario tiene 5 intentos para adivinar
-- - Retroalimentación: SUBE, BAJA, GOOD
-- - Bloqueo de 15s tras 5 fallos
-- Plataforma: Basys 3 (Artix-7)
--------------------------------------------------------------------
entity top_juego is
    Port (
        clk       : in  STD_LOGIC;  -- Clock 100 MHz
        reset     : in  STD_LOGIC;  -- Reset (botón o señal externa)

        -- Entrada del jugador
        btnc      : in  STD_LOGIC;  -- Confirmar intento
        sw        : in  STD_LOGIC_VECTOR(3 downto 0);  -- Número ingresado (0-15)

        -- Salidas visuales
        anodos    : out STD_LOGIC_VECTOR(3 downto 0);
        segmentos : out STD_LOGIC_VECTOR(6 downto 0);
        
        -- LEDs para mostrar intentos restantes (opcional)
        leds      : out STD_LOGIC_VECTOR(15 downto 0)
    );
end top_juego;

architecture Behavioral of top_juego is

    --------------------------------------------------------------------
    -- SEÑALES INTERNAS
    --------------------------------------------------------------------
    
    -- Botón limpio
    signal btnc_clean : STD_LOGIC;
    
    -- Número objetivo (generado aleatoriamente)
    signal numero_objetivo : STD_LOGIC_VECTOR(3 downto 0);
    
    -- Resultado de comparación: "00"=menor, "01"=igual, "10"=mayor
    signal resultado_comparacion : STD_LOGIC_VECTOR(1 downto 0);
    
    -- Contador de intentos
    signal intentos_restantes : STD_LOGIC_VECTOR(2 downto 0);  -- 0-5
    signal sin_intentos       : STD_LOGIC;
    
    -- Temporizador
    signal enable_1hz         : STD_LOGIC;
    signal segundos_bloqueo   : STD_LOGIC_VECTOR(3 downto 0);  -- 0-15
    signal bloqueo_activo     : STD_LOGIC;
    signal fin_bloqueo        : STD_LOGIC;
    
    -- Señales de control de la FSM
    signal modo_inicio        : STD_LOGIC;
    signal modo_jugando       : STD_LOGIC;
    signal modo_sube          : STD_LOGIC;
    signal modo_baja          : STD_LOGIC;
    signal modo_acierto       : STD_LOGIC;
    signal modo_fail          : STD_LOGIC;
    signal modo_bloqueo       : STD_LOGIC;
    
    signal generar_numero     : STD_LOGIC;
    signal decrementar_intento : STD_LOGIC;
    signal reset_intentos     : STD_LOGIC;
    signal iniciar_bloqueo    : STD_LOGIC;
    
    -- Para display de multiplexado
    signal enable_1khz        : STD_LOGIC;

begin

    --------------------------------------------------------------------
    -- DEBOUNCER para botón de confirmación
    --------------------------------------------------------------------
    DEB_C: entity work.debouncer_c
        port map (
            clk      => clk,
            reset    => reset,
            btn_in   => btnc,
            btn_out  => btnc_clean
        );

    --------------------------------------------------------------------
    -- GENERADOR PSEUDOALEATORIO (0-15)
    --------------------------------------------------------------------
    GENERADOR: entity work.generador_pseudoaleatorio
        port map (
            clk             => clk,
            reset           => reset,
            generar         => generar_numero,
            numero_objetivo => numero_objetivo
        );

    --------------------------------------------------------------------
    -- COMPARADOR (mayor/menor/igual)
    --------------------------------------------------------------------
    COMPARADOR: entity work.comparador_juego
        port map (
            numero_ingresado => sw,
            numero_objetivo  => numero_objetivo,
            resultado        => resultado_comparacion
        );

    --------------------------------------------------------------------
    -- CONTADOR DE INTENTOS (5 → 0)
    --------------------------------------------------------------------
    CONTADOR: entity work.contador_intentos_5
        port map (
            clk            => clk,
            reset          => reset,
            reset_intentos => reset_intentos,
            decrementar    => decrementar_intento,
            intentos       => intentos_restantes,
            sin_intentos   => sin_intentos
        );


    --------------------------------------------------------------------
    -- TEMPORIZADOR DE BLOQUEO (15 segundos)
    --------------------------------------------------------------------
    TIMER_15S: entity work.temporizador_bloqueo_15s
        port map (
            clk            => clk,
            reset          => reset,
            enable_1hz     => enable_1hz,
            start_bloqueo  => iniciar_bloqueo,
            segundos_out   => segundos_bloqueo,
            bloqueo_activo => bloqueo_activo,
            fin_bloqueo    => fin_bloqueo
        );

    --------------------------------------------------------------------
    -- FSM DEL JUEGO (controlador principal)
    --------------------------------------------------------------------
    FSM: entity work.fsm_juego
        port map (
            clk           => clk,
            reset         => reset,
            
            -- Entradas
            btnc          => btnc_clean,
            resultado     => resultado_comparacion,
            sin_intentos  => sin_intentos,
            fin_bloqueo   => fin_bloqueo,
            
            -- Salidas de modo
            modo_inicio      => modo_inicio,
            modo_jugando     => modo_jugando,
            modo_sube        => modo_sube,
            modo_baja        => modo_baja,
            modo_acierto     => modo_acierto,
            modo_fail        => modo_fail,
            modo_bloqueo     => modo_bloqueo,
            
            -- Señales de control
            generar_numero     => generar_numero,
            decrementar_intento => decrementar_intento,
            reset_intentos     => reset_intentos,
            iniciar_bloqueo    => iniciar_bloqueo
        );

-------------------------------------------------------------
    -- CONTROLADOR DE DISPLAY (visualización)
    --------------------------------------------------------------------
    DISPLAY: entity work.display_controller
        port map (
            clk              => clk,
            reset            => reset,
            
            -- Modos de seguridad (desactivados)
            modo_config       => '0',
            modo_verificacion => '0',
            modo_bloqueo_30   => '0',
            
            -- Modos de juego (activados según FSM)
            modo_inicio_juego => modo_inicio,
            modo_jugando      => modo_jugando,
            modo_sube         => modo_sube,
            modo_baja         => modo_baja,
            modo_acierto      => modo_acierto,
            modo_fail         => modo_fail,
            modo_bloqueo_15   => modo_bloqueo,
            
            -- Datos
            intentos_seg   => (others => '0'),
            intentos_juego => intentos_restantes,
            segundos_30    => (others => '0'),
            segundos_15    => segundos_bloqueo,
            
            -- Salidas físicas
            anodos    => anodos,
            segmentos => segmentos
        );

    --------------------------------------------------------------------
    -- VISUALIZACIÓN EN LEDs (intentos restantes)
    -- Muestra de 5 a 0 LEDs encendidos según intentos
    --------------------------------------------------------------------
    process(intentos_restantes)
    begin
        case intentos_restantes is
            when "101" =>  -- 5 intentos
                leds <= "0000000000011111";  -- LD4-LD0 encendidos
            when "100" =>  -- 4 intentos
                leds <= "0000000000001111";  -- LD3-LD0 encendidos
            when "011" =>  -- 3 intentos
                leds <= "0000000000000111";  -- LD2-LD0 encendidos
            when "010" =>  -- 2 intentos
                leds <= "0000000000000011";  -- LD1-LD0 encendidos
            when "001" =>  -- 1 intento
                leds <= "0000000000000001";  -- LD0 encendido
            when others =>  -- 0 intentos
                leds <= "0000000000000000";  -- Todos apagados
        end case;
    end process;

end Behavioral;
