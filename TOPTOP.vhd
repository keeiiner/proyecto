library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--------------------------------------------------------------------
-- Módulo: top_proyecto_completo
-- Descripción: Sistema completo con seguridad y juego
-- Flujo:
--   1. Usuario configura clave (BTNL)
--   2. Usuario intenta acceder (3 intentos)
--   3. Si accede correctamente → habilita JUEGO
--   4. Juego "Adivina el Número" (5 intentos)
--   5. Reset para reiniciar todo el sistema
-- Plataforma: Basys 3 (Artix-7)
--------------------------------------------------------------------
entity top_proyecto_completo is
    Port (
        -- Entradas físicas
        clk       : in  STD_LOGIC;  -- 100 MHz
        reset_btn : in  STD_LOGIC;  -- Botón de reset global
        
        -- Botones
        btnl      : in  STD_LOGIC;  -- Configurar clave (seguridad)
        btnc      : in  STD_LOGIC;  -- Confirmar acción
        
        -- Switches (entrada de datos)
        sw        : in  STD_LOGIC_VECTOR(3 downto 0);
        
        -- Salidas visuales
        anodos    : out STD_LOGIC_VECTOR(3 downto 0);
        segmentos : out STD_LOGIC_VECTOR(6 downto 0);
        leds      : out STD_LOGIC_VECTOR(15 downto 0)
    );
end top_proyecto_completo;

architecture Behavioral of top_proyecto_completo is

    --------------------------------------------------------------------
    -- SEÑALES GLOBALES
    --------------------------------------------------------------------
    signal reset : STD_LOGIC;
    
    -- Control de flujo principal
    signal acceso_concedido : STD_LOGIC := '0';  -- '1' = usuario autenticado
    signal juego_activo     : STD_LOGIC := '0';  -- '1' = juego en ejecución
    
    --------------------------------------------------------------------
    -- SEÑALES DEL MÓDULO DE SEGURIDAD
    --------------------------------------------------------------------
    signal btnl_clean_seg : STD_LOGIC;
    signal btnc_clean_seg : STD_LOGIC;
    
    signal clave_guardada : STD_LOGIC_VECTOR(3 downto 0);
    signal clave_ok       : STD_LOGIC;
    
    signal intentos_seg        : STD_LOGIC_VECTOR(1 downto 0);
    signal sin_intentos_seg    : STD_LOGIC;
    signal segundos_bloqueo_30 : STD_LOGIC_VECTOR(5 downto 0);
    signal fin_bloqueo_30      : STD_LOGIC;
    
    signal modo_config_seg       : STD_LOGIC;
    signal modo_verificacion_seg : STD_LOGIC;
    signal modo_bloqueo_seg      : STD_LOGIC;
    
    signal reset_intentos_seg      : STD_LOGIC;
    signal decrementar_intento_seg : STD_LOGIC;
    signal guardar_clave_sig       : STD_LOGIC;
    signal iniciar_bloqueo_seg     : STD_LOGIC;
    
    --------------------------------------------------------------------
    -- SEÑALES DEL MÓDULO DE JUEGO
    --------------------------------------------------------------------
    signal btnc_clean_juego : STD_LOGIC;
    
    signal numero_objetivo        : STD_LOGIC_VECTOR(3 downto 0);
    signal resultado_comparacion  : STD_LOGIC_VECTOR(1 downto 0);
    
    signal intentos_juego      : STD_LOGIC_VECTOR(2 downto 0);
    signal sin_intentos_juego  : STD_LOGIC;
    signal segundos_bloqueo_15 : STD_LOGIC_VECTOR(3 downto 0);
    signal fin_bloqueo_15      : STD_LOGIC;
    
    signal modo_inicio_juego : STD_LOGIC;
    signal modo_jugando      : STD_LOGIC;
    signal modo_sube         : STD_LOGIC;
    signal modo_baja         : STD_LOGIC;
    signal modo_acierto      : STD_LOGIC;
    signal modo_fail         : STD_LOGIC;
    signal modo_bloqueo_juego : STD_LOGIC;
    
    signal generar_numero         : STD_LOGIC;
    signal decrementar_intento_juego : STD_LOGIC;
    signal reset_intentos_juego     : STD_LOGIC;
    signal iniciar_bloqueo_juego    : STD_LOGIC;
    
    --------------------------------------------------------------------
    -- SEÑALES COMPARTIDAS
    --------------------------------------------------------------------
    signal enable_1hz  : STD_LOGIC;
    signal enable_1khz : STD_LOGIC;
    
    -- Señales multiplexadas para el display
    signal anodos_seg    : STD_LOGIC_VECTOR(3 downto 0);
    signal segmentos_seg : STD_LOGIC_VECTOR(6 downto 0);
    signal anodos_juego    : STD_LOGIC_VECTOR(3 downto 0);
    signal segmentos_juego : STD_LOGIC_VECTOR(6 downto 0);

begin

    --------------------------------------------------------------------
    -- RESET GLOBAL
    --------------------------------------------------------------------
    reset <= reset_btn;

    --------------------------------------------------------------------
    -- LÓGICA DE CONTROL PRINCIPAL
    -- Determina si está en modo SEGURIDAD o JUEGO
    --------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            acceso_concedido <= '0';
            juego_activo <= '0';
            
        elsif rising_edge(clk) then
            -- Transición de SEGURIDAD a JUEGO
            if acceso_concedido = '0' and modo_verificacion_seg = '1' and clave_ok = '1' and btnc_clean_seg = '1' then
                acceso_concedido <= '1';
                juego_activo <= '1';
            end if;
            
            -- Mantener en juego mientras esté activo
            -- (podría agregar condición para salir del juego)
        end if;
    end process;

    --------------------------------------------------------------------
    -- MULTIPLEXADO DE SALIDAS (SEGURIDAD vs JUEGO)
    --------------------------------------------------------------------
    -- Selecciona qué módulo controla el display según el estado
    anodos    <= anodos_juego    when juego_activo = '1' else anodos_seg;
    segmentos <= segmentos_juego when juego_activo = '1' else segmentos_seg;
    
    -- LEDs: muestra estado actual
    process(juego_activo, intentos_seg, intentos_juego)
    begin
        if juego_activo = '0' then
            -- Modo SEGURIDAD: LEDs superiores para intentos (LD15-LD13)
            leds <= (others => '0');
            case intentos_seg is
                when "11" => leds(15 downto 13) <= "111";  -- 3 intentos
                when "10" => leds(15 downto 13) <= "110";  -- 2 intentos
                when "01" => leds(15 downto 13) <= "100";  -- 1 intento
                when others => leds(15 downto 13) <= "000";  -- 0 intentos
            end case;
        else
            -- Modo JUEGO: LEDs inferiores para intentos (LD4-LD0)
            leds <= (others => '0');
            case intentos_juego is
                when "101" => leds(4 downto 0) <= "11111";  -- 5 intentos
                when "100" => leds(4 downto 0) <= "01111";  -- 4 intentos
                when "011" => leds(4 downto 0) <= "00111";  -- 3 intentos
                when "010" => leds(4 downto 0) <= "00011";  -- 2 intentos
                when "001" => leds(4 downto 0) <= "00001";  -- 1 intento
                when others => leds(4 downto 0) <= "00000";  -- 0 intentos
            end case;
        end if;
    end process;


    --                    MÓDULO DE SEGURIDAD

    --------------------------------------------------------------------
    -- DEBOUNCERS (SEGURIDAD)
    --------------------------------------------------------------------
    DEB_L_SEG: entity work.debouncer_l
        port map (
            clk     => clk,
            reset   => reset,
            btn_in  => btnl,
            btn_out => btnl_clean_seg
        );
    
    DEB_C_SEG: entity work.debouncer_c
        port map (
            clk     => clk,
            reset   => reset,
            btn_in  => btnc,
            btn_out => btnc_clean_seg
        );

    --------------------------------------------------------------------
    -- ALMACENAMIENTO DE CLAVE
    --------------------------------------------------------------------
    ALMACEN_CLAVE: entity work.guardar_clave
        port map (
            clk            => clk,
            reset          => reset,
            guardar        => guardar_clave_sig,
            clave_in       => sw,
            clave_guardada => clave_guardada
        );

    --------------------------------------------------------------------
    -- COMPARADOR DE CLAVE
    --------------------------------------------------------------------
    VERIFICAR_CLAVE: entity work.verificar_clave
        port map (
            clave_ingresada => sw,
            clave_guardada  => clave_guardada,
            correcta        => clave_ok
        );

    --------------------------------------------------------------------
    -- CONTADOR DE INTENTOS (3 intentos)
    --------------------------------------------------------------------
    CONTADOR_SEG: entity work.contador_intentos_3
        port map (
            clk            => clk,
            reset          => reset,
            reset_intentos => reset_intentos_seg,
            fallo_intento    => decrementar_intento_seg,
            intentos       => intentos_seg,
            sin_intentos   => sin_intentos_seg
        );

    --------------------------------------------------------------------
    -- TEMPORIZADOR DE BLOQUEO (30 segundos)
    --------------------------------------------------------------------
    TIMER_30S: entity work.temporizador_bloqueo
        port map (
            clk            => clk,
            reset          => reset,
            start_bloqueo  => iniciar_bloqueo_seg,
            segundos_out   => segundos_bloqueo_30,
            bloqueo_activo => open,  -- No usado
            fin_bloqueo    => fin_bloqueo_30
        );

    --------------------------------------------------------------------
    -- FSM DE SEGURIDAD
    --------------------------------------------------------------------
    FSM_SEG: entity work.fsm_seguridad
        port map (
            clk           => clk,
            reset         => reset,
            
            btnl          => btnl_clean_seg,
            btnc          => btnc_clean_seg,
            clave_correcta => clave_ok,
            sin_intentos  => sin_intentos_seg,
            fin_bloqueo   => fin_bloqueo_30,
            
            modo_config       => modo_config_seg,
            modo_verificacion => modo_verificacion_seg,
            modo_bloqueo      => modo_bloqueo_seg,
            acceso_concedido  => open,  -- Usamos nuestra propia señal
            
            reset_intentos      => reset_intentos_seg,
            decrementar_intento => decrementar_intento_seg,
            guardar_clave       => guardar_clave_sig,
            iniciar_bloqueo     => iniciar_bloqueo_seg
        );

    --------------------------------------------------------------------
    -- DISPLAY SEGURIDAD
    --------------------------------------------------------------------
    DISPLAY_SEG: entity work.display_controller
        port map (
            clk              => clk,
            reset            => reset,
            
            -- Modos de seguridad
            modo_config       => modo_config_seg,
            modo_verificacion => modo_verificacion_seg,
            modo_bloqueo_30   => modo_bloqueo_seg,
            
            -- Modos de juego desactivados
            modo_inicio_juego => '0',
            modo_jugando      => '0',
            modo_sube         => '0',
            modo_baja         => '0',
            modo_acierto      => '0',
            modo_fail         => '0',
            modo_bloqueo_15   => '0',
            
            -- Datos
            intentos_seg   => intentos_seg,
            intentos_juego => (others => '0'),
            segundos_30    => segundos_bloqueo_30,
            segundos_15    => (others => '0'),
            
            -- Salidas
            anodos    => anodos_seg,
            segmentos => segmentos_seg
        );

    --                       MÓDULO DE JUEGO

    --------------------------------------------------------------------
    -- DEBOUNCER (JUEGO)
    --------------------------------------------------------------------
    DEB_C_JUEGO: entity work.debouncer_c
        port map (
            clk     => clk,
            reset   => reset,
            btn_in  => btnc,
            btn_out => btnc_clean_juego
        );

    --------------------------------------------------------------------
    -- GENERADOR PSEUDOALEATORIO
    --------------------------------------------------------------------
    GENERADOR: entity work.generador_pseudoaleatorio
        port map (
            clk             => clk,
            reset           => reset,
            generar         => generar_numero,
            numero_objetivo => numero_objetivo
        );

    --------------------------------------------------------------------
    -- COMPARADOR (JUEGO)
    --------------------------------------------------------------------
    COMPARADOR_JUEGO: entity work.comparador_juego
        port map (
            numero_ingresado => sw,
            numero_objetivo  => numero_objetivo,
            resultado        => resultado_comparacion
        );

    --------------------------------------------------------------------
    -- CONTADOR DE INTENTOS (5 intentos)
    --------------------------------------------------------------------
    CONTADOR_JUEGO: entity work.contador_intentos_5
        port map (
            clk            => clk,
            reset          => reset,
            reset_intentos => reset_intentos_juego,
            decrementar    => decrementar_intento_juego,
            intentos       => intentos_juego,
            sin_intentos   => sin_intentos_juego
        );

    --------------------------------------------------------------------
    -- TEMPORIZADOR DE BLOQUEO (15 segundos)
    --------------------------------------------------------------------
    TIMER_15S: entity work.temporizador_bloqueo_15s
        port map (
            clk            => clk,
            reset          => reset,
            enable_1hz     => enable_1hz,
            start_bloqueo  => iniciar_bloqueo_juego,
            segundos_out   => segundos_bloqueo_15,
            bloqueo_activo => open,
            fin_bloqueo    => fin_bloqueo_15
        );

    --------------------------------------------------------------------
    -- FSM DE JUEGO
    --------------------------------------------------------------------
    FSM_JUEGO: entity work.fsm_juego
        port map (
            clk           => clk,
            reset         => reset,
            
            btnc          => btnc_clean_juego,
            resultado     => resultado_comparacion,
            sin_intentos  => sin_intentos_juego,
            fin_bloqueo   => fin_bloqueo_15,
            
            modo_inicio      => modo_inicio_juego,
            modo_jugando     => modo_jugando,
            modo_sube        => modo_sube,
            modo_baja        => modo_baja,
            modo_acierto     => modo_acierto,
            modo_fail        => modo_fail,
            modo_bloqueo     => modo_bloqueo_juego,
            
            generar_numero     => generar_numero,
            decrementar_intento => decrementar_intento_juego,
            reset_intentos     => reset_intentos_juego,
            iniciar_bloqueo    => iniciar_bloqueo_juego
        );

    --------------------------------------------------------------------
    -- DISPLAY JUEGO
    --------------------------------------------------------------------
    DISPLAY_JUEGO: entity work.display_controller
        port map (
            clk              => clk,
            reset            => reset,
            
            -- Modos de seguridad desactivados
            modo_config       => '0',
            modo_verificacion => '0',
            modo_bloqueo_30   => '0',
            
            -- Modos de juego
            modo_inicio_juego => modo_inicio_juego,
            modo_jugando      => modo_jugando,
            modo_sube         => modo_sube,
            modo_baja         => modo_baja,
            modo_acierto      => modo_acierto,
            modo_fail         => modo_fail,
            modo_bloqueo_15   => modo_bloqueo_juego,
            
            -- Datos
            intentos_seg   => (others => '0'),
            intentos_juego => intentos_juego,
            segundos_30    => (others => '0'),
            segundos_15    => segundos_bloqueo_15,
            
            -- Salidas
            anodos    => anodos_juego,
            segmentos => segmentos_juego
        );
end Behavioral;