library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

--------------------------------------------------------------------
-- Módulo: top_sistema_seguridad_basys3
-- Descripción: Sistema de seguridad con acceso por clave de 4 bits
-- Plataforma: Basys 3 (Artix-7)
--------------------------------------------------------------------
entity top_sistema_seguridad_basys3 is
    Port (
        clk       : in  STD_LOGIC;  -- Clock 100 MHz de Basys 3
        reset_btn : in  STD_LOGIC;  -- Botón de reset

        -- Botones de usuario
        btnl      : in  STD_LOGIC;  -- Entrar a modo configuración
        btnc      : in  STD_LOGIC;  -- Confirmar acción

        -- Switches para ingresar clave (SW0-SW3)
        sw        : in  STD_LOGIC_VECTOR(3 downto 0);

        -- Display 7 segmentos
        anodos    : out STD_LOGIC_VECTOR(3 downto 0);
        segmentos : out STD_LOGIC_VECTOR(6 downto 0)
    );
end top_sistema_seguridad_basys3;

architecture Behavioral of top_sistema_seguridad_basys3 is

    --------------------------------------------------------------------
    -- Señales internas
    --------------------------------------------------------------------
    signal reset : STD_LOGIC;

    -- Botones limpios (después de debouncing)
    signal btnl_clean : STD_LOGIC;
    signal btnc_clean : STD_LOGIC;

    -- Señales de clave
    signal clave_guardada : STD_LOGIC_VECTOR(3 downto 0);
    signal clave_ok       : STD_LOGIC;

    -- Contador de intentos
    signal intentos_bin : STD_LOGIC_VECTOR(1 downto 0);
    signal sin_intentos : STD_LOGIC;

    -- Temporizador de bloqueo
    signal segundos_bloqueo : STD_LOGIC_VECTOR(5 downto 0);
    signal bloqueo_activo   : STD_LOGIC;
    signal fin_bloqueo      : STD_LOGIC;

    -- Señales de control de la FSM
    signal modo_config       : STD_LOGIC;
    signal modo_verificacion : STD_LOGIC;
    signal modo_bloqueo      : STD_LOGIC;
    signal acceso_concedido  : STD_LOGIC;  -- ✅ Agregar si usas este estado

    signal reset_intentos      : STD_LOGIC;
    signal decrementar_intento : STD_LOGIC;  -- ✅ Agregar
    signal guardar_clave_sig   : STD_LOGIC;
    signal iniciar_bloqueo     : STD_LOGIC;

begin

    --------------------------------------------------------------------
    -- Reset (puede ser directo o invertido según tu Basys 3)
    --------------------------------------------------------------------
    reset <= reset_btn;

    --------------------------------------------------------------------
    -- DEBOUNCERS para botones
    --------------------------------------------------------------------
    deb_l : entity work.debouncer_l
        port map (
            clk      => clk,
            reset    => reset,
            btn_in   => btnl,
            btn_out  => btnl_clean
        );

    deb_c : entity work.debouncer_c
        port map (
            clk      => clk,
            reset    => reset,
            btn_in   => btnc,
            btn_out  => btnc_clean
        );

    --------------------------------------------------------------------
    -- ALMACENAMIENTO de clave
    -- Captura DIRECTAMENTE desde switches cuando guardar='1'
    --------------------------------------------------------------------
    registro_clave : entity work.guardar_clave
        port map (
            clk            => clk,
            reset          => reset,
            guardar        => guardar_clave_sig,
            clave_in       => sw,              -- ✅ DIRECTO desde switches
            clave_guardada => clave_guardada
        );

    --------------------------------------------------------------------
    -- COMPARADOR de clave
    -- Compara switches actuales con clave guardada
    --------------------------------------------------------------------
    verificador : entity work.verificar_clave
        port map (
            clave_ingresada => sw,             -- ✅ DIRECTO desde switches
            clave_guardada  => clave_guardada,
            correcta        => clave_ok
        );

    --------------------------------------------------------------------
    -- CONTADOR de intentos (3 → 2 → 1 → 0)
    --------------------------------------------------------------------
    contador : entity work.contador_intentos_3
        port map (
            clk            => clk,
            reset          => reset,
            reset_intentos => reset_intentos,
           fallo_intento    => decrementar_intento,  --  Desde FSM
            intentos       => intentos_bin,
            sin_intentos   => sin_intentos
        );

    --------------------------------------------------------------------
    -- TEMPORIZADOR de bloqueo (30 segundos)
    --------------------------------------------------------------------
    timer30 : entity work.temporizador_bloqueo
        port map (
            clk            => clk,
            reset          => reset,
            start_bloqueo  => iniciar_bloqueo,
            segundos_out   => segundos_bloqueo,
            bloqueo_activo => bloqueo_activo,
            fin_bloqueo    => fin_bloqueo
        );

    --------------------------------------------------------------------
    -- FSM de seguridad (controlador principal)
    --------------------------------------------------------------------
    fsm : entity work.fsm_seguridad
        port map (
            clk            => clk,
            reset          => reset,

            -- Entradas
            btnl           => btnl_clean,
            btnc           => btnc_clean,
            clave_correcta => clave_ok,
            sin_intentos   => sin_intentos,
            fin_bloqueo    => fin_bloqueo,

            -- Salidas de modo
            modo_config       => modo_config,
            modo_verificacion => modo_verificacion,
            modo_bloqueo      => modo_bloqueo,
            acceso_concedido  => acceso_concedido,  -- ✅ Si lo tienes

            -- Señales de control
            reset_intentos      => reset_intentos,
            decrementar_intento => decrementar_intento,  -- ✅ Agregar
            guardar_clave       => guardar_clave_sig,
            iniciar_bloqueo     => iniciar_bloqueo
        );

    --------------------------------------------------------------------
    -- VISUALIZACIÓN en displays de 7 segmentos
    --------------------------------------------------------------------
DISPLAY: entity work.display_controller
    port map (
        clk => clk,
        reset => reset,
        
        -- Activar solo modos de seguridad
        modo_config       => modo_config,
        modo_verificacion => modo_verificacion,
        modo_bloqueo_30   => modo_bloqueo,
        
        -- Desactivar modos de juego
        modo_inicio_juego => '0',
        modo_jugando      => '0',
        modo_sube         => '0',
        modo_baja         => '0',
        modo_acierto      => '0',
        modo_fail         => '0',
        modo_bloqueo_15   => '0',
        
        -- Datos
        intentos_seg   => intentos_bin,
        intentos_juego => (others => '0'),
        segundos_30    => segundos_bloqueo,
        segundos_15    => (others => '0'),
        
        -- Salidas
        anodos    => anodos,
        segmentos => segmentos
    );

end Behavioral;
