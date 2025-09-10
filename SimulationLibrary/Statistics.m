classdef Statistics < handle
    %STATISTICS Gestisce e analizza i dati della simulazione
    %
    % Questa classe raccoglie, memorizza e analizza le principali metriche
    % generate durante una simulazione discreta a eventi.
    %
    % Funzionalità principali:
    % - Raccolta dati: lunghezze code, tempi di attesa, tempi di servizio,
    %   utilizzo risorse, log eventi.
    % - Reset: re-inizializzazione delle statistiche per nuove repliche.
    % - Calcolo indicatori: lunghezza media di coda, tempo medio di attesa,
    %   tempo medio di servizio, utilizzo medio delle risorse.
    % - Report: raccolta e salvataggio dei principali KPI (key performance indicators).
    %
    % Proprietà pubbliche:
    % - queueLengths : struct queueLengths.entityName = [time, length; ...]
    % - waitTimes : struct waitTimes.entityName = [t1, t2, ...]
    % - serviceTimes : struct serviceTimes.entityName = [s1, s2, ...]
    % - resourceArea : struct resourceArea.entityName = area sotto la curva busy
    %       Integrale numerico del tempo durante cui la risorsa è stata occupata.
    % -  eventLog : cell Cell array Nx2: {time, description}
    %       Log generale degli eventi avvenuti durante la simulazione.
    % - contatori : struct contatori.nome = valore
    % - stopFlag : logical 
    % - stopThreshold : struct stopThreshold.nome = soglia
    %

    properties
        queueLengths struct  
        waitTimes struct  
        serviceTimes struct  
        resourceArea struct  
        eventLog cell  
        contatori struct 
        stopFlag logical = false  
        stopThreshold struct 
    end
    
    methods

        %%% Costruttore
        function obj = Statistics(initialStopTr)
            obj.queueLengths = struct();
            obj.waitTimes = struct();
            obj.serviceTimes = struct();
            obj.resourceArea = struct();
            obj.eventLog = {};

            obj.contatori = struct();
            obj.stopFlag = false;
            obj.stopThreshold = initialStopTr;  
        end
        
        %%% RESET
        % Metodo che permette di resettare le statistiche per poter operare
        % una nuova simulazione
        %
        function reset(obj, initialStopTr)
            obj.queueLengths = struct();
            obj.waitTimes = struct();
            obj.serviceTimes = struct();
            obj.resourceArea = struct();
            obj.eventLog = {};
            obj.stopFlag = false;
            obj.stopThreshold = initialStopTr; 

            fields = fieldnames(obj.contatori);
            for i = 1:length(fields)
                obj.contatori.(fields{i}) = 0;  
            end
        end
        
        %%% RECORD
        % Metodo che permette di registrare l'avvenimento di un evento
        % aggiornando il contatore, se il contatore supera la soglia di
        % stop, alzo un flag e interrompo la simulazione perché ho
        % raggiunto la statistica richiesta
        %
        function record(obj, name)
            if ~isfield(obj.contatori, name)
                obj.contatori.(name) = 0;
            end
            obj.contatori.(name) = obj.contatori.(name) + 1;

            if obj.contatori.(name) >= obj.stopThreshold.(name)
                obj.stopFlag = true;
            end
        end

        %%% RECORDQUEUELENGTH 
        % Registra la lunghezza della coda di un'entità
        % riceve in input il nome dell'entità, l'istante di misurazione e
        % la lunghezza rilevata, crea una struct in cui associa ad ogni
        % entità una matrice le cui righe sono [time, length]
        %
        function recordQueueLength(obj, entityName, time, length)
            if ~isfield(obj.queueLengths, entityName)
                obj.queueLengths.(entityName) = [];
            end
            obj.queueLengths.(entityName)(end+1,:) = [time, length];
        end
        
        %%% RECORDWAITTIME
        % Metodo che permette di registrare un tempo di attesa per un'entità.
        % Riceve in input il nome dell'entità e il tempo di attesa rilevato.
        % Crea un campo nella struct associato all'entità (se non esiste)
        % e aggiunge il nuovo valore alla lista dei tempi di attesa.
        %
        function recordWaitTime(obj, entityName, waitTime)
            if ~isfield(obj.waitTimes, entityName)
                obj.waitTimes.(entityName) = [];
            end
            obj.waitTimes.(entityName)(end+1) = waitTime;
        end
        
        %%% RECORDSERVICETIME
        % Metodo che permette di registrare un tempo di servizio per un'entità.
        % Riceve in input il nome dell'entità e il tempo di servizio rilevato.
        % Crea un campo nella struct associato all'entità (se non esiste)
        % e aggiunge il nuovo valore alla lista dei tempi di servizio.
        %
        function recordServiceTime(obj, entityName, serviceTime)
            if ~isfield(obj.serviceTimes, entityName)
                obj.serviceTimes.(entityName) = [];
            end
            obj.serviceTimes.(entityName)(end+1) = serviceTime;
        end
        
        %%% RECORDRESOURCEUSAGE
        % Metodo che registra lo stato di utilizzo (busy) di una risorsa.
        % Riceve in input il nome della risorsa, il tempo corrente e
        % lo stato di busy (0 = libero, 1 = occupato).
        % Calcola l'area sotto la curva di busy per valutare l'utilizzo.
        % Si assume che il metodo venga chiamato ogni volta che lo 
        % stato della risorsa cambia oppure periodicamente.
        %
        function recordResourceUsage(obj, entityName, time, busyStruct)
            
            if ~isfield(obj.resourceArea, entityName)
                obj.resourceArea.(entityName) = struct();
            end
            
            fields = fieldnames(busyStruct);
            for k = 1:numel(fields)
                res = fields{k};
                currBusy = busyStruct.(res);
            
                if ~isfield(obj.resourceArea.(entityName), res)
                    obj.resourceArea.(entityName).(res) = struct( ...
                        'area',     0, ...
                        'lastTime', time, ...
                        'lastBusy', currBusy ...
                    );
                    continue;
                end
            
                entry = obj.resourceArea.(entityName).(res);
                dt = time - entry.lastTime;
            
                entry.area = entry.area + entry.lastBusy * dt;
            
                entry.lastTime = time;
                entry.lastBusy = currBusy;
            
                obj.resourceArea.(entityName).(res) = entry;
            end
        end
        
        %%% RECORDEVENT
        % Metodo che registra un generico evento della simulazione.
        % Riceve in input il timestamp e una descrizione testuale dell'evento.
        % Memorizza l'informazione nel log eventi.
        %
        function recordEvent(obj, time, description)
            obj.eventLog(end+1,:) = {time, description};
        end
        
        %%% COMPUTEAVERAGEQUEUELENGTH
        % Metodo che calcola la lunghezza media della coda per un'entità.
        % L'integrale della lunghezza coda nel tempo viene diviso per il tempo finale.
        % Se non ci sono dati sufficienti restituisce NaN.
        %
        function avgLen = computeAverageQueueLength(obj, entityName)
            endTime= obj.queueLengths.(entityName)(end,1);

            if ~isfield(obj.queueLengths, entityName)
                avgLen = NaN; return;
            end
            data = obj.queueLengths.(entityName);
            if size(data,1) < 2 || endTime <= 0
                avgLen = NaN; return;
            end
            area = 0;
            for i=2:size(data,1)
                dt = data(i,1) - data(i-1,1);
                area = area + data(i-1,2) * dt; % lunghezza pesata sul tempo 
            end
            avgLen = area / endTime;
        end
        
        %%% COMPUTEAVERAGEWAITTIME
        % Metodo che calcola il tempo medio di attesa per un'entità.
        % Restituisce la media dei tempi raccolti.
        %
        function avgWait = computeAverageWaitTime(obj, entityName)
            if ~isfield(obj.waitTimes, entityName) || isempty(obj.waitTimes.(entityName))
                avgWait = NaN; return;
            end
            avgWait = mean(obj.waitTimes.(entityName));
        end
        
        %%% COMPUTEAVERAGESERVICETIME
        % Metodo che calcola il tempo medio di servizio per un'entità.
        % Restituisce la media dei tempi raccolti.
        %
        function avgServ = computeAverageServiceTime(obj, entityName)
            if ~isfield(obj.serviceTimes, entityName) || isempty(obj.serviceTimes.(entityName))
                avgServ = NaN; return;
            end
            avgServ = mean(obj.serviceTimes.(entityName));
        end
        
        %%% COMPUTEUTILIZATION
        % Metodo che calcola l'utilizzo medio di una risorsa.
        % Riceve in input il nome della risorsa e la sua capacità.
        % Calcola l'area sotto la curva di busy e la normalizza
        % rispetto al prodotto tra capacità e tempo finale.
        %
        function utils = computeUtilization(obj, entityName, capacity)

            if ~isfield(obj.resourceArea, entityName)
                utils = struct(); return;
            end
            areaStruct = obj.resourceArea.(entityName);        
            fields = fieldnames(areaStruct);
            utils = struct();
            for i = 1:numel(fields)
                res    = fields{i};
                entry  = areaStruct.(res);
                busyArea = entry.area;
                endTime  = entry.lastTime;  % istante finale per risorsa
        
                if endTime <= 0
                    utils.(res) = NaN;
                    continue;
                end
        
                if isstruct(capacity)
                    if isfield(capacity, res)
                        capRes = capacity.(res);
                    else
                        error('computeUtilization: manca capacity.%s', res);
                    end
                else
                    capRes = capacity;
                end        
                utils.(res) = busyArea / (capRes * endTime);
            end
        end
        
        %%% COLLECTSUMMARY
        % Metodo che raccoglie un vettore di statistiche della simulazione.
        % Include contatori, lunghezze medie di coda, tempi medi di attesa,
        % tempi medi di servizio e utilizzi medi delle risorse.
        % Restituisce un vettore con questi valori in sequenza.
        %
        function summary = collectSummary(obj)
            summary = [];

            fields = fieldnames(obj.contatori);
            for i = 1:numel(fields)
                name = fields{i};
                value = obj.contatori.(name);
                summary(end+1) = value;
            end
            entList = fieldnames(obj.queueLengths);
            for i = 1:numel(entList)
                e = entList{i};
                summary(end+1) = obj.computeAverageQueueLength(e);
            end
            entList = fieldnames(obj.waitTimes);
            for i = 1:numel(entList)
                e = entList{i};
                summary(end+1) = obj.computeAverageWaitTime(e);
            end
            entList = fieldnames(obj.serviceTimes);
            for i = 1:numel(entList)
                e = entList{i};
                summary(end+1) = obj.computeAverageServiceTime(e);
            end

            entNames = fieldnames(obj.resourceArea); 
            for i = 1:numel(entNames)
                entity = entNames{i};
                utils = obj.computeUtilization(entity, 1);
            
                resNames = fieldnames(utils);
                for j = 1:numel(resNames)
                    res = resNames{j};
                    u   = utils.(res);
                    summary(end+1) = u;   
                end
            end

        end
    
        %%% COMPUTECONFINT
        % Metodo che calcola le medie e intervalli di confidenza al 95% 
        % per un insieme di repliche della simulazione.
        % Riceve una matrice (repliche x statistiche) e restituisce due vettori:
        % - means: le medie campionarie
        % - ci: gli intervalli di confidenza (calcolati con una t di student)
        %
        function [means, ci] = computeConfInt(~, data)
            % data: matrix (repliche x statistiche)
            means = mean(data, 1);
            sem = std(data, 0, 1) ./ sqrt(size(data,1)); 
            tval = tinv(0.975, size(data,1)-1); 
            ci = tval * sem;
        end
    
        %%% WRITESCENARIOSUMMARY
        % Metodo che scrive su file i risultati della simulazione per un dato scenario.
        % Riceve i parametri dello scenario, le medie, gli intervalli di confidenza
        % e il nome del file su cui scrivere.
        %
        function writeScenarioSummary(~, ScenarioParams, means, ci, filename)
            
            fid = fopen(filename, 'a');
            if fid == -1
                error('Impossibile aprire il file %s', filename);
            end
            % Scrivi parametri
            paramFields = fieldnames(ScenarioParams);
            for i = 1:numel(paramFields)
                val = ScenarioParams.(paramFields{i});
                fprintf(fid, '%-12s', sprintf('%.1f',val));
            end
            fprintf(fid, '| ');
    
            % Scrivi medie + intervalli di confidenza
            for i = 1:numel(means)
                fprintf(fid, '%-25s', sprintf('%.3f ± %.3f', means(i), ci(i)));
            end
            fprintf(fid, '\n');
            fclose(fid);
            
        end
    
        %%% WRITEHEADERSUMMARY
        % Metodo che scrive l'intestazione della tabella dei risultati su file.
        % Viene chiamato alla prima replica del primo scenario.
        % Scrive i nomi dei parametri e delle statistiche calcolate.
        %
        function writeHeaderSummary(obj, ScenarioParams, rep, s, filename)
            
            % Verifica se dobbiamo scrivere l'intestazione
            if rep == 1 && s == 1
                fid = fopen(filename, 'a');
                if fid == -1
                    error('Impossibile aprire il file %s', filename);
                end
                % Parametri
                paramFields = fieldnames(ScenarioParams);
                for i = 1:numel(paramFields)
                    fprintf(fid, '%-12s', paramFields{i});
                end
                fprintf(fid, '| ');
        
                % Statistiche che vogliamo
                fields = fieldnames(obj.contatori);
                for i = 1:numel(fields)
                    name = fields{i};
                    fprintf(fid,'%-25s', name);
                end
                
                qEnts = fieldnames(obj.queueLengths);
                for i = 1:numel(qEnts)
                    fprintf(fid, '%-25s', ['AvgQueueLen_' qEnts{i}]);
                end
                
                wEnts = fieldnames(obj.waitTimes);
                for i = 1:numel(wEnts)
                    fprintf(fid, '%-25s', ['AvgWait_' wEnts{i}]);
                end
                
                sEnts = fieldnames(obj.serviceTimes);
                for i = 1:numel(sEnts)
                    fprintf(fid, '%-25s', ['AvgServ_' sEnts{i}]);
                end
                              
                entNames = fieldnames(obj.resourceArea); 
                for i = 1:numel(entNames)
                    entity = entNames{i};
                    utils = obj.computeUtilization(entity, 1);
                
                    resNames = fieldnames(utils);
                    for j = 1:numel(resNames)
                        res = resNames{j};
                        fprintf(fid, '%-25s', ['Util_' res]);  
                    end
                end
                
                fprintf(fid, '\n');
                fclose(fid);
            end
        end
            

%         function setStopThreshold(obj, name, N)
%             if ~isfield(obj.stopThreshold, name)
%                 obj.stopThreshold.(name) = inf;
%             end
%             obj.stopThreshold.(name) = N;
%         end


        function displayReport(obj) %vecchia versione
            % DISPLAYREPORT Stampa il report finale e genera grafici
            fprintf('=== Statistics Report ===\n');
            
            disp('--- Contatori ---');
            fields = fieldnames(obj.contatori);
            for i = 1:numel(fields)
                name = fields{i};
                value = obj.contatori.(name);
                fprintf('%s: %d\n', name, value);
            end

            
            qEnts = fieldnames(obj.queueLengths);
            for i=1:numel(qEnts)
                e = qEnts{i};
                avgL = obj.computeAverageQueueLength(e);
                fprintf('Entity %s - Avg. queue length: %.6f\n', e, avgL);
            end
            
            wEnts = fieldnames(obj.waitTimes);
            for i=1:numel(wEnts)
                e = wEnts{i};
                avgW = obj.computeAverageWaitTime(e);
                fprintf('Entity %s - Avg. wait time: %.6f\n', e, avgW);
                
                % Plot della media cumulativa del tempo di attesa
                wt = obj.waitTimes.(e);
                cumMean = cumsum(wt) ./ (1:length(wt));
                figure;
                plot(1:length(wt), cumMean, 'b-', 'LineWidth', 1.5);
                grid on;
                xlabel('Customer index');
                ylabel('Cumulative mean wait time');
                title(['Cumulative mean wait time - ', e]);
            end
            
            sEnts = fieldnames(obj.serviceTimes);
            for i=1:numel(sEnts)
                e = sEnts{i};
                avgS = obj.computeAverageServiceTime(e);
                fprintf('Entity %s - Avg. service time: %.6f\n', e, avgS);
            end
            
            rEnts = fieldnames(obj.resourceArea);
            for i=1:numel(rEnts)
                e = rEnts{i};
                if endsWith(e, '_lastBusy'), continue; end
                util = obj.computeUtilization(e, 1);  % Assumo capacità 1
                fprintf('Entity %s - Utilization: %.6f%%\n', e, util * 100);
            end
            
            fprintf('========================\n');
        end



    end 
end

