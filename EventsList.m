classdef EventsList < handle
    % EVENTSLIST Gestisce la lista degli eventi per la simulazione discreta
    %
    % Questa classe si occupa della gestione della coda degli eventi 
    % futuri. La lista mantiene gli eventi ordinati cronologicamente in modo che 
    % il prossimo evento da eseguire sia sempre in testa.
    %
    % La classe implementa:
    % 1) Un metodo per costruire e inizializzare la lista eventi.
    % 2) Un metodo per verificare se la lista eventi è finita (vuota o con 
    %    tutti gli eventi futuri oltre l'orizzonte temporale).
    % 3) Un registro (cell array) che memorizza la sequenza degli 
    %    eventi eseguiti, utile per output e visualizzazioni.
    % 4) Un metodo per aggiornare la lista mantenendo l'ordinamento 
    %    cronologico degli eventi futuri.
    %
    % STRUTTURA DELLA CODA:
    % Gli eventi sono rappresentati come oggetti (eventObj) contenenti almeno:
    %   - name : stringa che identifica il tipo di evento
    %   - time : istante temporale dell'evento
    %
    % Proprietà pubbliche:
    % - entities : cell Lista dei nomi delle entità gestite dal simulatore.
    % - eventQueue : cell array Nx1 Coda ordinata degli eventi futuri: {eventObj}
    % - eventHistory : cell array Mx1  Coda di oggetti {eventObj}
    % - eventCounters : containers.Map Mappa (nome evento -> numero esecuzioni)
    % - initial : cell array Lista iniziale degli eventi per permettere il reset della simulazione.
    %
    % COSTRUTTORE:
    %   obj = EventsList(entities, initialEvents)
    %       entities : cell array di nomi delle entità gestite
    %       initialEvents : cell array degli eventi iniziali {eventObj}
    %
   
    properties
        entities cell
        eventQueue cell    
        eventHistory cell   
        eventCounters  containers.Map 
        initial cell
    end

    methods

        %%% Costruttore
        function obj = EventsList(entities, initialEvents)
            obj.entities = entities;
            obj.eventQueue = obj.orderEvents(initialEvents(:)); % ordina già in input
            obj.eventHistory = {};
            obj.eventCounters = containers.Map('KeyType','char','ValueType','double');
            obj.initial = initialEvents;
        end

        %%% RESET 
        % Reinizializza la lista eventi e i contatori
        % Ripristina la coda agli eventi iniziali e azzera la cronologia e i contatori
        %
        function reset(obj)
            obj.eventQueue = obj.orderEvents(obj.initial); 
            obj.eventHistory = {};
            obj.eventCounters = containers.Map('KeyType','char','ValueType','double');
        end

        %%% ISFINISHED
        % Verifica se la lista eventi è vuota
        % Restituisce true se non ci sono eventi futuri
        %
        function finished = isFinished(obj)
            if isempty(obj.eventQueue)
                finished = true;
            else
                finished = false;
            end
        end

        %%% GETNEXTEVENT:
        % ordina il cell array, (serve un metodo specifico per i cell array)
        % prelevo dalla testa del cell array,
        % aggiorno il contatore di eventi di quel tipo che si sono
        % realizzati, registro anche l'evento nella cronologia eventi
        %
        function [eventObj, time] = getNextEvent(obj)
            if obj.isFinished()
                error('Nessun evento disponibile o orizzonte superato')
            end
            obj.eventQueue = obj.orderEvents(obj.eventQueue);
            eventObj = obj.eventQueue{1};
            time = eventObj.time;

            % Aggiorna cronologia
            obj.eventHistory{end+1,1} = eventObj;
            % Aggiorna contatore
            name = eventObj.name;
            if isKey(obj.eventCounters, name)
                obj.eventCounters(name) = obj.eventCounters(name) + 1;
            else
                obj.eventCounters(name) = 1;
            end

            % Rimuovi dalla testa
            obj.eventQueue(1) = [];
        end
         
        %%% ADDEVENT 
        % Aggiunge un nuovo evento alla lista
        % L'evento deve avere un nome diverso dagli eventi già presenti
        %
        function addEvent(obj, eventObj)
            if ~isempty(obj.eventQueue)
                names = cellfun(@(e) e.name, obj.eventQueue, 'UniformOutput', false);
                if any(strcmp(names, eventObj.name))
                    error('Evento "%s" già presente nella coda.', eventObj.name);
                end
            end
            obj.eventQueue = [obj.eventQueue; {eventObj}];
            obj.eventQueue = obj.orderEvents(obj.eventQueue);
        end

        %%% PLOTHISTORY 
        % Visualizza cronologia eventi
        % Mostra scatter plot tempo vs nome evento eseguito
        %
        function plotHistory(obj)
            if isempty(obj.eventHistory)
                disp('Nessun evento eseguito.');
                return;
            end
            times = cellfun(@(e) e.time, obj.eventHistory);
            names = cellfun(@(e) e.name, obj.eventHistory, 'UniformOutput', false);

            figure;
            scatter(times, double(categorical(names)), 'filled');
            xlabel('Tempo');
            ylabel('Nome evento');
            title('Cronologia esecuzione eventi');
            grid on;
        end

        %%% PLOTTIMELINE
        % disegna una linea temporale degli eventi
        %   plotTimeline()                → tutto l’orizzonte
        %   plotTimeline(tMin, tMax)      → solo eventi in [tMin,tMax]
        function plotTimeline(obj, tMin, tMax)
            
            if isempty(obj.eventHistory)
                disp('Nessun evento eseguito.');
                return;
            end
    
            times = cellfun(@(e) e.time, obj.eventHistory);
            names = cellfun(@(e) e.name, obj.eventHistory, 'UniformOutput', false);
    
            if nargin >= 3
                mask = times >= tMin & times <= tMax;
                times = times(mask);
                names = names(mask);
                if isempty(times)
                    warning('Nessun evento nell''intervallo [%g, %g].', tMin, tMax);
                    return;
                end
            end
    
            % Trova i tipi unici e assegna un marker a ciascuno
            [uniqueNames, ~, idx] = unique(names);
            markers = {'o','s','^','d','v','p','h','x','+','*'};
            nTypes = numel(uniqueNames);
    
            figure; hold on;
            for k = 1:nTypes
                sel = (idx == k);
                scatter(times(sel), k*ones(sum(sel),1), 100, ...
                        markers{mod(k-1,numel(markers))+1}, 'filled');
            end
            hold off;
    
            yticks(1:nTypes);
            yticklabels(uniqueNames);
            xlabel('Tempo');
            ylabel('Tipo di evento');
            if nargin >= 3
                xlim([tMin, tMax]);
                title(sprintf('Timeline eventi in [%g, %g]', tMin, tMax));
            else
                title('Timeline completa degli eventi');
            end
            grid on;
        end
    
    end

    methods (Access = private)
        
        %%% ORDEREVENTS  
        % Ordina eventi per tempo crescente
        % Restituisce il cell array ordinato in base al tempo
        %
        function sorted = orderEvents(~, events)
            times = cellfun(@(e) e.time, events);
            [~, idx] = sort(times);
            sorted = events(idx);
        end

    end
end
