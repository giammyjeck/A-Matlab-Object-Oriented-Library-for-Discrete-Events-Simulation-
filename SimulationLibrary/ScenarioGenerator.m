classdef ScenarioGenerator < handle
    % SCENARIOGENERATOR Gestisce la creazione di scenari.
    %
    % Questa classe permette di costruire un piano degli esperimenti e
    % definendo delle configurazioni di parametri, ognuna costutisce uno
    % scenario su cui simulare, la configurazione viene passata al
    % SimulatorManager che simula e calcola le statistiche
    % 
    % Proprietà pubbliche:
    % - repForScenario : double numero di ripetizioni per ogni scenario
    % - timeHorizon : double orizzonte temporale di simulazione 
    % - currentConfi : struct  contiene ogni parametro e il livello
    % corrispondente
    % - baseConfig : struct configurazione iniziale salvata per reset 
    % - values : dizionario che ha in chiave il parametro e come oggetto un
    % array di livelli a cui simulare il parametro
    % - dimsLevels : (1,:) double array con numero di livelli per parametro
    %

    properties
        repForScenarios double {mustBeNonnegative, mustBeInteger} = 1
        timeHorizon double {mustBeNonnegative, mustBeInteger} 
        currentConfig struct
        baseConfig struct
        values containers.Map
        dimsLevels (1,:) double
    end
    
    methods

        %%% Costruttore
        function obj = ScenarioGenerator(initialConfig,rep,time,values)
            obj.currentConfig = initialConfig;
            obj.repForScenarios = rep;
            obj.timeHorizon = time;
            obj.baseConfig = initialConfig;
            obj.values = values;
            
            % Calcola dimensioni
            flds = fieldnames(initialConfig);
            obj.dimsLevels = zeros(1, numel(flds));
            for k = 1:numel(flds)
                key = flds{k};
                if isKey(values, key)
                    obj.dimsLevels(k) = numel(values(key));
                else
                    obj.dimsLevels(k) = 1;
                end
            end            
        end

        %%% NUMSCENARIOS
        % Calcola il numero totale di scenari da eseguire, il piano degli
        % esperimenti ha dimensione data dal numero di livelli che testiamo
        % per ogni parametro
        %
        function total = numScenarios(obj)
            total = prod(obj.dimsLevels);
        end
        
        %%% OBTAINSCENARIO
        % Prende in input il numero di scenario corrente e restituisce la
        % configurazione di parametri, aggiornata impostando ogni parametro
        % al livello corrispondente allo scenario
        %
        function parametri = obtainScenario(obj, n)
            if n < 1 || n > obj.numScenarios()
                error('Scenario index %d out of bounds (1..%d)', n, obj.numScenarios());
            end

            flds = fieldnames(obj.baseConfig);
            numFields = numel(flds);
            idxs = zeros(1, numFields);
            
            idx = n - 1; 
            for k = numFields:-1:1
                if obj.dimsLevels(k) > 1
                    idxs(k) = mod(idx, obj.dimsLevels(k)) + 1;
                    idx = floor(idx / obj.dimsLevels(k));
                else
                    idxs(k) = 1;
                end
            end
            
            % Aggiorno
            parametri = obj.baseConfig;
            for k = 1:numFields
                key = flds{k};
                if isKey(obj.values, key)
                    vec = obj.values(key);
                    parametri.(key) = vec(idxs(k));
                end
            end
            obj.currentConfig = parametri;
        end

        %%% GETSEASONALRATE
        % Questo metodo viene utilizzato negli handler delle entità che
        % gestiscono gli eventi, per simulare eventi futuri sfruttando
        % il fattore di stagionalità. 
        % In pratica aggiorna il rate con cui simulo eventi futuri, 
        % modificandoloin base al tempo corrente della simulazione e alla 
        % configurazione attuale del fattore di stagionalità.
        %
        function rate = getSeasonalRate(obj, baseRate, clockTime)
            
            % clockTime in minuti, giornata = 1440 min
            f = obj.currentConfig.Stagionalita; % fattore stagionalità
            if f == 0
                rate = baseRate;
                return;
            end
            % Sinusoide con picco a mezzogiorno
            rate = baseRate * (1 + f * sin(2*pi*clockTime-360/1440));
            rate = max(rate, eps); % evita rate negativi o zero
        end

    end

end


    
